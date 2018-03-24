
import sys
import random
# sys.path.append('../../')
sys.path = ['../../']+sys.path

from expy import *

start(fullscreen=False,mouse_visible=True,sample_rate=22050)

def trial(stim):

    drawText('+')
    show(0.5)
    clear()

    sound = loadSound('test/data/task1/' + stim['stimuli'] + '.WAV')  # Load the wav file
    sound = changeOnTracks(sound,changeVolume,[0,1]) #play only through right ear
    playSound(sound)  # Play the wav file
    print(stim['stimuli'])
    
    key,RT = waitForResponse({key_.F: 'tone2', key_.J: 'tone4'}) # Waiting for pressing 'F' or 'J'

    clear()
    show(1)

    return key,RT

def block(blockID):
    readStimuli('test/data/trial_list_pilot_2.csv', query='block==%s' %(blockID))
    stimuli= readStimuli('test/data/trial_list_pilot_2.csv', query='block==%s' %(blockID))
    random.shuffle(stimuli)

    alertAndGo('The experiment will start in 3s')
    
    result= []
    for t in stimuli:
        result.append(trial(t))

    saveResult(result,stim=stimuli)

shared.subject = getInput('please enter your subject ID:')

instruction(shared.setting['instruction4'])

for blockID in range(2):
    block(blockID+1)

alertAndQuit('Thanks for your participation :)')
