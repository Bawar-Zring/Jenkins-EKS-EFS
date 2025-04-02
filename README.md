# Jenkins on EKS with EFS
## Overview
This project sets up a Jenkins CI/CD environment on an AWS EKS cluster with persistent storage using Amazon EFS. It leverages Terraform for infrastructure automation and Kubernetes manifests for deployment.
## Prerequisites
- AWS CLI
- Terraform

## Setup Instructions
1. Terraform init & apply

   ```
   terraform init
   terraform apply
   ```

2. Configure kubectl for EKS
   Ensure kubectl is configured to interact with your EKS cluster.
   ```
    aws eks update-kubeconfig --region us-east-1 --name eks-cluster
   ```

3. Associate OIDC Provider
OIDC is required for IAM authentication in Kubernetes.
   ```
    eksctl utils associate-iam-oidc-provider --cluster eks-cluster --approve --region us-east-1
   ```

4. Get OIDC Endpoint
   Retrieve the OIDC endpoint for IAM role configuration.
   ```
    aws eks describe-cluster --name eks-cluster --query "cluster.identity.oidc.issuer" --output text
   ```

5. Update IAM Trust Policy
   Modify trust-policy.json by updating:
   - AWS Account ID
   - Region
   - OIDC endpoint
   - Service account name (ensure it matches system:serviceaccount:serviceaccount)
     Reapply Terraform to update the IAM role.


6. Retrieve EFS Information
   Get the EFS ID and Access Point ID:
     ```
       aws efs describe-file-systems --query "FileSystems[*].FileSystemId" --output text
       aws efs describe-access-points --query "AccessPoints[*].AccessPointId" --output text
     ```

7. Update Persistent Volume (PV)
   Edit PV.yaml and update volumeHandle with the retrieved EFS ID.
   ```
        volumeHandle: <fs-XXXXXXXXX>::<fsap-XXXXXXX>
   ```

8. Apply Kubernetes Manifests
   Deploy the necessary storage and Jenkins resources
   ```
      kubectl apply -f K8s/
   ```

10. Verify Jenkins Deployment
   Access Jenkins via the LoadBalancer DNS.
     ```
       http://<LoadBalancer-DNS>:8080
     ```

10. Jenkins Initial Setup
   - Install necessary plugins
   - Create an admin user


11. Test Jenkins Persistence
   Delete the Jenkins pod and verify persistence
      ```
       kubectl delete pod <jenkins-pod-id>
      ```

Refresh the Jenkins UI, and you should still see the login screen, confirming EFS persistence.

# Conclusion
This setup ensures a scalable and persistent Jenkins deployment on AWS EKS, leveraging Terraform, Kubernetes, and Amazon EFS.







