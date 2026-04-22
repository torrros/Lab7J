pipeline {
    agent any

    tools {
        terraform 'terraform'
        ansible 'ansible'
    }

    environment {
        SSH_CRED_ID = 'lab7'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Apply') {
            steps {
		withCredentials([sshUserPrivateKey(credentialsId: 'lab7', keyFileVariable: 'SSH_KEY_FILE', publicKeyVariable: 'PUB_KEY')]) {
                sh "terraform init"
                sh "TF_VAR_ssh_public_key='${PUB_KEY}' terraform apply -auto-approve"

                script {
                    env.VM_IP = sh(script: "terraform output -raw vm_ip", returnStdout: true).trim()
                    if (!env.VM_IP) {
                        error "IP address not found! Terraform output is empty."
                    }
                     echo "Successfully retrieved VM IP: ${env.VM_IP}"
            }
        }
    } 
}   


        stage('Ansible Deploy') {
            steps {
                sshagent([SSH_CRED_ID]) {
                    sh """
                    ansible-playbook -i '${env.VM_IP},' \
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
            sh "terraform destroy -auto-approve"
        }
        always {
            cleanWs()
        }
    }
}
