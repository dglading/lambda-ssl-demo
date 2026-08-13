AWS Private Lambda with Custom SSL Certificate Trust Store
==========================================================

A production-ready AWS CloudFormation solution for deploying a private AWS Lambda function into an existing VPC and private subnet. The function performs outbound HTTP/HTTPS URL status checks while routing egress traffic through a 3rd-party firewall (such as **Zscaler Internet Access** or **Palo Alto**) performing SSL/TLS inspection.

To prevent SSL verification failures when the firewall re-signs certificates, the Lambda function dynamically auto-discovers custom CA certificates from a private S3 bucket and injects them into its local trust store (/tmp/custom-ca-bundle.pem) during cold start.

### Key Components

*   **Existing VPC Deployment**: Deploys into user-supplied VPC and private subnets (VpcId, SubnetIds, RouteTableIds).
    
*   **S3 Gateway VPC Endpoint**: Ensures traffic between Lambda and S3 remains strictly private within the AWS network.
    
*   **Private S3 Bucket**: Configured with BlockPublicAccess, SSE-S3 encryption, and an IAM bucket policy permitting access to VPC Endpoint requests and AWS Console management.
    
*   **Cold-Start Auto-Discovery**: Automatically scans S3 for .crt, .pem, or .cer certificate files (e.g., ZscalerRootCertificate-2048-SHA256-Feb2025.crt).
    
*   **Robust Certificate Extraction**: Strips UTF-8 Byte Order Marks (BOM), normalizes CRLF line endings, extracts clean ASCII PEM blocks, and converts binary DER certificates automatically.
    
*   **System & Custom CA Merge**: Combines native Amazon Linux CAs (/etc/pki/tls/certs/ca-bundle.crt) with custom firewall root/intermediate CAs into /tmp/custom-ca-bundle.pem.
    
*   **Response Body & IP Tracking**: Returns the HTTP response status code, parsed body (JSON or text snippet), headers, and the container's private IPv4 address (privateIp).
    

🚀 Prerequisites
----------------

1.  **AWS CLI & Privileges**: Access to an AWS account with permissions to deploy CloudFormation stacks, IAM roles, S3 buckets, and Lambda functions.
    
2.  **Existing Network Infrastructure**:
    
    *   An existing **VPC ID** (vpc-xxxxxxxxx)
        
    *   One or more **Private Subnet IDs** (subnet-xxxxxxxxx)
        
    *   Corresponding **Route Table IDs** (rtb-xxxxxxxxx)
        
3.  **Firewall CA Certificate**: A Root or Intermediate CA certificate from your SSL inspection firewall (.pem, .crt, or .cer).
    

🛠️ Quick Start & Deployment
----------------------------

### Step 1: Deploy the CloudFormation Stack

Deploy via the AWS Console or using the AWS CLI:

> **Note:** Leave CustomCertificatePem empty if uploading multi-certificate chains or files directly to S3.

### Step 2: Upload Your SSL Inspection Certificate to S3

Upload your firewall root/intermediate CA certificate to the newly created S3 bucket (CertBucketName output):

🧪 Testing & Verification
-------------------------

1.  Open the **AWS Lambda Console**.
    
2.  Select the function named URLStatusChecker (do not select S3ProvisionerFunction).
    
3.  Under the **Test** tab, create a test event with the target URL: in JSON format e.g.

{
  "url": "https://ip.zscaler.com/?json"
}

    
4.  Click **Test**. Successful execution returns statusCode: 200, the container's private IP, and the parsed response body:
    

🔒 How the Trust Store is Built
-------------------------------

On cold start, the Lambda runtime executes the following sequence:

1.  **System CAs**: Reads native Amazon Linux root certificates (/etc/pki/tls/certs/ca-bundle.crt).
    
2.  **S3 Auto-Discovery**: Lists objects in the configured bucket to locate certificate files matching .crt, .pem, or .cer.
    
3.  **Format Parsing (**extract\_pem\_certificates**)**:
    
    *   Uses utf-8-sig to strip UTF-8 BOM headers (\\xef\\xbb\\xbf).
        
    *   Extracts clean ASCII certificate blocks (-----BEGIN CERTIFICATE-----).
        
    *   Converts binary DER files using ssl.DER\_cert\_to\_PEM\_cert().
        
4.  **Bundle Generation**: Appends custom certificates to the system CAs and saves to /tmp/custom-ca-bundle.pem.
    
5.  **Context Injection**: Passes ssl.create\_default\_context(cafile='/tmp/custom-ca-bundle.pem') explicitly to outbound HTTP requests.
    

🏷️ Tagging & Compliance
------------------------

All stack resources include standardized resource tags:

*   Name: URLStatusChecker
    
*   ManagedBy: CloudFormation
    
*   SecurityInspection: Enabled
    

Additional stack-level tags configured during deployment will automatically propagate to all underlying resources.
