#!/bin/bash

set -e

# declare -a dataParalellisms=("4" "3" "2" "1")
# declare -a executorCores=("1250m" "1125m" "1000m")
# declare -a learningRates=("0.01" "0.02" "0.04")
declare -a dataParalellisms=("4")
declare -a executorCores=("1250m")
declare -a learningRates=("0.01")
declare -a batchSizes=("16" "32" "48" "64" "80" "96" "112" "128" "144" "160" "176" "192" "208" "224" "240" "256" "272" "288" "304" "320" "336" "352" "368" "384" "400" "416" "432" "448" "464" "480" "496" "512" "528" "544" "560" "576" "592" "608" "624" "640" "656" "672" "688" "704" "720" "736" "752" "768" "784" "800" "816" "832" "848" "864" "880" "896" "912" "928" "944" "960" "976" "992" "1008" "1024")

for dataParallelism in ${dataParalellisms[@]]}; do
	for executorCore in ${executorCores[@]}; do
		for learningRate in ${learningRates[@]}; do
			for batchSize in ${batchSizes[@]}; do
				for run in {1..3}; do
					echo "Starting run: $dataParallelism $executorCore $learningRate $batchSize $run"

					cd 'configs/tasks'
					filename="example_arrival_config.json"
					newDataParallelism="          \"dataParallelism\": \"$dataParallelism\","
					newExecutorCore="          \"executorCores\": \"$executorCore\","
					newLearningRate="          \"learningRate\": \"$learningRate\","
					newBatchSize="          \"batchSize\": \"$batchSize\","
					sed -i '' -e "s/.*dataParallelism.*/$newDataParallelism/" $filename
					sed -i '' -e "s/.*executorCores.*/$newExecutorCore/" $filename
					sed -i '' -e "s/.*learningRate.*/$newLearningRate/" $filename
					sed -i '' -e "s/.*batchSize.*/$newBatchSize/" $filename

					cat example_arrival_config.json

					cd ../..

					DOCKER_BUILDKIT=1 docker build . --tag gcr.io/cse4215-qpe-jdentoonder/fltk
					docker push gcr.io/cse4215-qpe-jdentoonder/fltk

					cd charts
					helmUninstall=$(helm uninstall -n test learner 2>&1) || :
					echo "$helmUninstall"
					if [ "$helmUninstall" != 'Error: uninstall: Release not loaded: learner: release: not found' ] && [ "$helmUninstall" != 'release "learner" uninstalled' ]
					then
						echo "Error uninstalling orchestrator"
						exit 1
					fi
					sleep 10

					kubectl delete pytorchjobs.kubeflow.org --all --all-namespaces
					sleep 10
					helm install learner ./orchestrator -n test -f fltk-values.yaml
					cd ..

					echo "Waiting until a pod has started training"

					podsHaveStarted=false
					while [ "$podsHaveStarted" = "false" ]
					do
						runningPodsStarted=$(kubectl get pods -n test | grep -E 'trainjob.*Running' || :)
						if [[ ! -z "$runningPodsStarted" ]]
						then
							echo "A training job pod has started!"
							podsHaveStarted=true
						fi
						sleep 2
					done

					jobPodName=$(kubectl get pods -n test | grep -m 1 -E 'trainjob.*Running' || :)
					echo "$jobPodName,$dataParallelism,$executorCore,$learningRate,$batchSize,$run," >> experimentsBatchSize.csv

					podsAreRunning=true
					while [ "$podsAreRunning" = "true" ]
					do
						echo "Waiting until all pods have terminated"
						runningPods=$(kubectl get pods -n test | grep -E 'trainjob.*(Running|ContainerCreating|Pending|Error|Terminating|PodInitializing)' || :)
						if [ -z "$runningPods" ]
						then
							echo "All pods are done!"
							podsAreRunning=false
						fi
						sleep 30
					done
				done
			done
		done
	done
done
