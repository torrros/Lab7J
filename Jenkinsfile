pipeline {
    agent any
    environment {
        TF_HOME = tool 'terraform'
        ANSIBLE_HOME = tool 'ansible'
        SSH_CRED_ID = 'lab7'
    }
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Terraform Apply') {
            steps {
                sh "${TF_HOME}/terraform init"
                sh "${TF_HOME}/terraform apply -auto-approve"
                script {
                    env.VM_IP = sh(script: "${TF_HOME}/terraform output -raw vm_ip", returnStdout: true).trim()
                    if (!env.VM_IP) { error "IP address not found!" }
                }
            }
        }
        stage('Ansible Deploy') {
            steps {
                sshagent([SSH_CRED_ID]) {
                    sh """
                    ${ANSIBLE_HOME}/ansible-playbook -i '${env.VM_IP},' \
                    -u toros \
                    --extra-vars "ansible_ssh_common_args='-o StrictHostKeyChecking=no'" \
                    playbook.yml
                    """
                }
            }
        }
    }
    post {
        failure {
            echo "Deployment failed. Destroying infrastructure..."
            sh "${TF_HOME}/terraform destroy -auto-approve"
        }
        always {
            cleanWs()
        }
    }
}
