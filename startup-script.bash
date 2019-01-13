#!/bin/bash
# initialisation script for the Jenkins VM
latest_jenkins_war="https://updates.jenkins-ci.org/latest/jenkins.war"
# packages
debian_packages=( 
	"openjdk-8-jre"
	"openjdk-8-jdk"
	"maven"
	"wget"
)
apt update
apt upgrade -y
apt install -y ${debian_packages[@]}

# jenkins
useradd -m -U -u 700 jenkins
su - jenkins -c "wget ${latest_jenkins_war} -O ~"
jenkins_war="/home/jenkins/jenkins.war"
wget ${latest_jenkins_war} -O ${jenkins_war}
chmod +x ${jenkins_war}
chown -R jenkins:jenkins /home/jenkins

# jenkins-home disk
jenkins_home="/mnt/jenkins-home"
mount_disk() {
	mkdir -p ${jenkins_home}
	mount /dev/${partition} ${jenkins_home}
}
device_name=$(ls -al /dev/disk/by-id/ | grep Google_PersistentDisk_jenkins-home | awk '{print $NF}' | awk -F '/' '{print $NF}')
partition="${device_name}1"
if lsblk | grep "${partition}"; then
	printf "partition already created, mounting to ${jenkins_home}"
	mount_disk
else
	printf "partition on jenkins disk doesn't exist, creating now"
sfdisk /dev/${partition} << _EOF_
;	
_EOF_
	mount_disk
	chown -R jenkins:jenkins ${jenkins_home}
fi

# jenkins startup script
jenkins_startup_script="/home/jenkins/jenkins.bash"
cat > ${jenkins_startup_script} << EOF
#!/bin/bash
export JENKINS_HOME=${jenkins_home}
java -jar ~/jenkins.war
EOF
chmod +x ${jenkins_startup_script}
chown jenkins:jenkins ${jenkins_startup_script}

# jenkins service script
cat > /etc/systemd/system/jenkins.service << EOF
[Unit]
Description=Jenkins

[Service]
User=jenkins
WorkingDirectory=${jenkins_home}
ExecStart=${jenkins_startup_script}

[Install]
WantedBy=multi-user.target
EOF

# load and start the jenkins service
systemctl daemon-reload
systemctl start jenkins
systemctl enable jenkins
