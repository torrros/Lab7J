pipeline {
    agent any

    tools {
        terraform 'terraform'
        ansible 'ansible'
    }

    environment {
        SSH_CRED_ID = 'lab7'
        PUB_KEY_ID  = 'vm-pub-key'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([string(credentialsId: "${PUB_KEY_ID}", variable: 'PUBLIC_KEY')]) {
                    sh "terraform init"
                    sh "TF_VAR_ssh_public_key='${PUBLIC_KEY}' terraform apply -auto-approve"
                }
                script {
                    env.VM_IP = sh(script: "terraform output -raw vm_ip", returnStdout: true).trim()
                    if (!env.VM_IP) {
                        error "IP address not found! Terraform output is empty."
                    }
                    echo "Successfully retrieved VM IP: ${env.VM_IP}"
                }
            }
        }

        stage('Ansible Deploy') {
            steps {
                // Невелика затримка, щоб SSH сервіс у ВМ встиг ініціалізуватися
                sleep time: 30, unit: 'SECONDS'
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
            withCredentials([string(credentialsId: "${PUB_KEY_ID}", variable: 'PUBLIC_KEY')]) {
                sh "TF_VAR_ssh_public_key='${PUBLIC_KEY}' terraform destroy -auto-approve"
            }
        } // Додано закриваючу дужку для failure
        always {
            cleanWs()
        }
    }
}
