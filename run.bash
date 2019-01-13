set -e
region="europe-west2"
zone="europe-west2-c"

# the set the default project region and zone
gcloud config set compute/region ${region}
gcloud config set compute/zone ${zone}

# check for jenkins-home disk
disk_id=$(gcloud compute disks list --format "value(id)" --filter "name:jenkins-home AND zone:${zone}")
if [ -n "${disk_id}" ]; then 
	printf "Jenkins disk exists, it will be attached on the VM creation\n"
	# create a new jenkins VM and attach the jenkins home disk
	gcloud compute instances create jenkins \
		--disk "name=jenkins-home,device-name=jenkins-home" \
		--metadata-from-file "startup-script=startup-script.bash" \
		--tags jenkins
else 
	printf "Jenkins disk does not exist, it will be created along with the VM\n"
	# create a new jenkins VM with a new disk
	gcloud compute instances create jenkins \
		--create-disk "name=jenkins-home,size=200GB,device-name=jenkins-home,description='Disk containing the Jenkins home folder'" \
		--metadata-from-file "startup-script=startup-script.bash" \
		--tags jenkins
fi
# firewall rules
firewall_rule=$(gcloud compute firewall-rules list --format "value(name)" --filter "name:jenkins AND network:default")
if [ -z "${firewall_rule}" ]; then
	printf "firewall rule doesn't exist for Jenkins, creating one now"
	gcloud compute firewall-rules create jenkins --allow tcp:8080 --target-tags jenkins
fi
jenkins_ip=$(gcloud compute instances describe jenkins --format "value(networkInterfaces[0].accessConfigs[0].natIP)")
printf "Jenkins will be accessible shortly from this URL: http://${jenkins_ip}:8080\n"

