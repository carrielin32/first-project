
import sys
import random
import io
# sys.path.append('../../')
sys.path = ['../../']+sys.path

from expy import *

start(fullscreen=False,mouse_visible=True,sample_rate=22050)

def trial(stim):

    drawText('+')
    show(0.5)
    clear()

    sound = loadSound('data/task1/' + stim['stimuli'] + '.WAV')  # Load the wav file
    playSound(sound)  # Play thef wav file

    key,RT = waitForResponse({key_.F: 'tone2', key_.J: 'tone4'}) # Waiting for pressing 'F' or 'J'

    clear()
    show(1)

    return key,RT

def block(blockID):
    readStimuli('trial_list_pilot_3.csv', query='block==%s' %(blockID))
    stimuli= readStimuli('trial_list_pilot_3.csv', query='block==%s' %(blockID))
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
