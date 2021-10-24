import pandas as pd

from tensorboard.backend.event_processing.event_accumulator import EventAccumulator
event_acc = EventAccumulator('./experiment-results-batch')
event_acc.Reload()
# Show all tags in the log file
print(event_acc.Tags())

training_loss = [(s.step, s.wall_time, s.value) for s in event_acc.Scalars('training loss per epoch')]
accuracy = [(s.step, s.wall_time, s.value) for s in event_acc.Scalars('accuracy per epoch')]

data = pd.read_csv('experimentsBatchSize.csv')
file = -1
experiment_running_times = [None] * 192
experiment_accuracies = [None] * 192
exp_start_time = None
exp_end_time = None
exp_accuracy = None
for (idx, accuracy_item) in enumerate(accuracy):
    step = accuracy_item[0]
    wall_time = accuracy_item[1]
    val = accuracy_item[2]
    if step == 5:
        continue

    if step == 1:
        if idx != 0:
            running_time = exp_end_time - exp_start_time
            experiment_running_times[file] = running_time
            experiment_accuracies[file] = exp_accuracy
        exp_start_time = wall_time
        file = file + 1
    else:
        exp_end_time = wall_time
        exp_accuracy = val

    if step == 4 and idx + 1 < len(accuracy) and accuracy[idx + 1][0] == 5:
        exp_end_time = accuracy[idx + 1][1]
        exp_accuracy = accuracy[idx + 1][2]

running_time = exp_end_time - exp_start_time
experiment_running_times[file] = running_time
experiment_accuracies[file] = exp_accuracy

data['running_time'] = experiment_running_times
data['accuracy'] = experiment_accuracies
data.to_csv('experimentsOverviewBatchWithAccuracyAndTime.csv')

print(experiment_running_times)
