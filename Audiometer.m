function [Output] = Audiometer(Nblk,Freqs,Calib)
    if nargin<1
        Nblk = 1;
    end
     if nargin<2
        Freqs = [100 500 1000  2000 4000];
    end
    % params
    fs = 44100; % sampling rate
    len = 500; % tone length in ms
    ramp = 10; % ms ramp
    Nblk = 1; % number of blocks to run
    start_amp = 0.005; % this should be 90 db level
    % at 0.04 these are the db ratings
    % 100   - 50 dB
    % 500   - 55 dB
    % 1000  - 68 dB
    % 2000  - 70 dB
    % 4000  - 67 dB
    % generate tones 
    system('osascript -e "set Volume 10"');
    db_levels = [45 57 69 72 66];
    Instruction = imread('instructions\AudiometInstruction.png');
    Selection = imread('instructions\AudiometSelection.png');
    rs = round(ramp./1000*fs); % ramp length in samples
    
    for i = 1:length(Freqs)
        this_tone = sin(2*pi*Freqs(i)*[1/fs:1/fs:len/1000]);
        cos_ramp = (cos(0:(2*pi)/rs/2:2*pi)+1)/2;
        this_tone(1:rs) = this_tone(1:rs).*cos_ramp(end-rs+1:end);
        this_tone(end-rs+1:end) = this_tone(end-rs+1:end).*cos_ramp(1:rs);
        Stims(i,:) = this_tone;
    end
    
   
    subjCode = input('Please enter subject number: ');

    % psych toolbox setup    
    finishup = onCleanup(@() my_PsychClose);
    [AudPnt, VidPtr]=my_PsychInit(fs);
     if exist('Calib')
         run_calibration(VidPtr,AudPnt,Stims,Freqs,start_amp,fs);
         return;
     end
        
       
     
    WaitSecs(0.5);
    breakfontsize=Screen('TextSize', VidPtr, 30);
   
    spaceK = KbName('Space');
    RestrictKeysForKbCheck(spaceK);
    Screen('PutImage', VidPtr,Instruction);
    Screen(VidPtr,'Flip');
    KbWait(-1);  
    [keyDown, secs, keyCode] = KbCheck(-1);
    WaitSecs(0.5);

    % main experiment
    for i = 1:Nblk
        Output(i) = run_block(i,VidPtr,AudPnt,Stims,Freqs,start_amp,round(db_levels));
    end
    
    save(sprintf('Audiometer_Subj%d.mat',subjCode),'Output','Freqs');

    Screen(VidPtr,'Flip');
    thresh = zeros(2,length(Freqs));  
    for i = 1:Nblk
        thresh = thresh+Output.thresholds;
    end
    thresh = thresh./Nblk;
    plot(Freqs,thresh')
    WaitSecs(1);
    
function Output= run_block(blk,VidPtr,AudPnt,Stims,Freqs,start_amp,db_levels)
    down_dB_first = 15; % 15 db now when we start
    down_dB = 10;  % 10 db down 
    up_dB = 5;         % 5 db up
    thresh_level = 0.66;
    max_dB = 150;

    cnt = 1;
    key1 = KbName('1!');
    key2 = KbName('2@');
    RestrictKeysForKbCheck([key1 key2]);
    for ear = 1:2
        for st = 1:size(Stims,1)
                amp_level = start_amp;
                thresh = 0;
                level =db_levels(st)-round((log10(Freqs(st))-2)*10/5)*5;
                response_level = zeros(max_dB,1);
                count_level = zeros(max_dB,1);
                first_yes=0;first_no=0;
                while thresh==0
                    DrawFormattedText(VidPtr, ['+'], 'center', 'center', [255 255 255]);
                    Screen(VidPtr,'Flip');

                    if ear ==2 % right
                        PsychPortAudio('FillBuffer',AudPnt, [amp_level.*Stims(st,:); zeros(1,length(Stims))]);
                    else % left
                        PsychPortAudio('FillBuffer',AudPnt, [zeros(1,length(Stims));amp_level.*Stims(st,:)]);
                    end
                    PsychPortAudio('Start', AudPnt, 1, 0);
                    WaitSecs(0.5);
                    Screen('PutImage', VidPtr,imread('instructions\AudiometSelection.png'));
                    Screen(VidPtr,'Flip');
                    FlushEvents;
                    KbWait(-1);
                    [keyDown, secs, keyCode] = KbCheck(-1);
                    resp =find(keyCode,1,'first');
                    switch resp
                        case key1,      %yes
                                if first_yes==0 || first_no ==0
                                    amp_level = amp_level/(10^(down_dB_first/10));
                                    level = level-down_dB_first;                                 
                                else
                                     count_level(level) = count_level(level)+1;
                                     response_level(level) = response_level(level)+1;
                                     amp_level = amp_level/(10^(down_dB/10));
                                     if (response_level(level)./count_level(level) >= thresh_level) && (count_level(level)>3)
                                         thresh = level;
                                     end
                                     level = level-down_dB;   
                                     if level<=0, warning('below zero');
                                         level = 1;
                                     end
                                end
                                first_yes = 1;
                        case key2,      %no
                                if level<=0, warning('below zero');
                                         level = 1;
                                end
                                if first_yes && first_no
                                    count_level(level) = count_level(level)+1;
                                end
                                amp_level = amp_level*10^(up_dB/10);
                                level = level+up_dB;
                                first_no = 1;
                        otherwise, warning('bad response'); continue;
                    end
                    Output.trial(cnt,:) = [ear st thresh amp_level resp level];
                    fprintf('Ear %d, Stim %s, amp_level %1.6f, resp %c, level %d\n',Output.trial(cnt,1),Output.trial(cnt,2),Output.trial(cnt,4),char(Output.trial(cnt,5)+19),Output.trial(cnt,6));
                    Output.trial(cnt,:)
                    cnt = cnt+1;
                    save(sprintf('AutoSaveAudiometer_blk%d.mat',blk),'Output','Freqs');
                    if level>max_dB, thresh=Inf; break; end
                    
                end
                Output.thresholds(ear,st) = thresh;
        end
    end

function run_calibration(VidPtr,AudPnt,Stims,Freqs,start_amp,fs)

         DrawFormattedText(VidPtr, ['Calibration.\n press any key to pause and change setting. Space to quit.'], 'center', 'center', [255 255 255]);
         Screen(VidPtr,'Flip');
        while (1)
            cnt = 0;
            RestrictKeysForKbCheck([1:106]);
            FlushEvents;
            keyDown = 0;
            WaitSecs(0.5);
            while keyDown ==0
                cnt = mod(cnt,size(Stims,1));
                PsychPortAudio('FillBuffer',AudPnt, repmat(start_amp.*Stims(cnt+1,:),2,1));
                s = GetSecs;
                PsychPortAudio('Start', AudPnt, 1, 0);
                while (GetSecs-s)<length(Stims)/fs
                    [keyDown, secs, keyCode] = KbCheck(-1);
                    if keyDown, break; end
                end
                cnt = cnt+1;
            end
            if sum(keyCode) ==0     % more than one key presssed
                continue;
            end
                
            if find(keyCode,1,'first') == 44   % space 
                Output = start_amp;
                return;
            else
                DrawFormattedText(VidPtr,sprintf('Please type new value setting'),'center','center', [255 255 255]);
                %Screen(VidPtr,'Flip');
                
                FlushEvents;            
                ch = 0;
                thisReply = [];
                while int8(ch) ~=10 
                    DrawFormattedText(VidPtr, thisReply, 'center', 'center', [255 255 255]);
                    Screen(VidPtr,'Flip');
                    ch = GetChar();
                    if int8(ch) == 8
                        if length(thisReply)>0, thisReply(end) = []; end
                    else
                        thisReply = [thisReply ch];
                    end
                end
                start_amp =str2num(thisReply); if start_amp>1 || isempty(start_amp), start_amp = 1; end
                 DrawFormattedText(VidPtr, num2str(start_amp), 'center', 'center', [255 255 255]);
                Screen(VidPtr,'Flip');
            end
                
        end
        
    
    
function [AudPnt, VidPtr]=my_PsychInit(fs)
    % init audio
     Screen('Preference', 'SkipSyncTests', 1); 
    InitializePsychSound;
    AudPnt = PsychPortAudio('Open', [], [], 0, fs, 2);

    %setup screen
    screenNum=0; %%%%change to 2 in dual monitor setting
    [VidPtr,rect]=Screen('OpenWindow',screenNum);
    [xc,yc]=RectCenter(rect);
    HideCursor;
    black=BlackIndex(VidPtr);
    Screen('FillRect',VidPtr,black);

    priorityLevel=MaxPriority(['GetSecs'],['KbCheck']);

    breakfontsize=Screen('TextSize', VidPtr, 30);

    %disable keyboard input to command window
    ListenChar(2);
   

function my_PsychClose
    PsychPortAudio('Close');
    Screen('CloseAll');
    ShowCursor;
    ListenChar(0); %re-enable keyabord input to command window
