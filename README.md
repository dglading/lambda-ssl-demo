AWS Private Lambda with Custom SSL Certificate Trust Store
==========================================================

A production-ready AWS CloudFormation solution for deploying a private AWS Lambda function into an existing VPC and private subnet. The function performs outbound HTTP/HTTPS URL status checks while routing egress traffic through a 3rd-party firewall (such as **Zscaler Internet Access** or **Palo Alto**) performing SSL/TLS inspection.

To prevent SSL verification failures when the firewall re-signs certificates, the Lambda function dynamically auto-discovers custom CA certificates from a private S3 bucket and injects them into its local trust store (/tmp/custom-ca-bundle.pem) during cold start.

📐 Architecture Overview
------------------------

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   +-----------------------------------------------------------------------------------+  | AWS VPC                                                                           |  |                                                                                   |  |   +--------------------------+               +--------------------------------+   |  |   | Private Subnet           |               | S3 Gateway VPC Endpoint        |   |  |   |                          |               |                                |   |  |   |  +--------------------+  |               |  +--------------------------+  |   |  |   |  | Lambda Function    |  |===============>  | Private S3 Bucket        |  |   |  |   |  | (URLStatusChecker) |  |  S3 Traffic   |  | - bootstrap.sh           |  |   |  |   |  +---------+----------+  |               |  - custom-ca.pem / .crt  |  |   |  |   +------------|-------------+               +--------------------------+  |   |  |                |                                                              |   |  +----------------|--------------------------------------------------------------+   |                   | Egress Traffic                                                   |                   v                                                                  |      +--------------------------+                                                    |      | 3rd-Party Firewall       |                                                    |      | (SSL Inspection / Proxy) |                                                    |      +------------+-------------+                                                    |                   |                                                                  |                   v                                                                  |           Internet Targets                                                           |   `

### Key Components

*   **Existing VPC Deployment**: Deploys into user-supplied VPC and private subnets (VpcId, SubnetIds, RouteTableIds).
    
*   **S3 Gateway VPC Endpoint**: Ensures traffic between Lambda and S3 remains strictly private within the AWS network.
    
*   **Private S3 Bucket**: Configured with BlockPublicAccess, SSE-S3 encryption, and an IAM bucket policy permitting access to VPC Endpoint requests and AWS Console management.
    
*   **Cold-Start Auto-Discovery**: Automatically scans S3 for .crt, .pem, or .cer certificate files (e.g., ZscalerRootCertificate-2048-SHA256-Feb2025.crt).
    
*   **Robust Certificate Extraction**: Strips UTF-8 Byte Order Marks (BOM), normalizes CRLF line endings, extracts clean ASCII PEM blocks, and converts binary DER certificates automatically.
    
*   **System & Custom CA Merge**: Combines native Amazon Linux CAs (/etc/pki/tls/certs/ca-bundle.crt) with custom firewall root/intermediate CAs into /tmp/custom-ca-bundle.pem.
    
*   **Response Body & IP Tracking**: Returns the HTTP response status code, parsed body (JSON or text snippet), headers, and the container's private IPv4 address (privateIp).
    

📂 Repository Structure
-----------------------

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   .  ├── template.yaml       # AWS CloudFormation template (v1.0.4)  ├── bootstrap.sh        # Post-build trust store bootstrap script  └── README.md           # Deployment and operational documentation   `

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

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   aws cloudformation create-stack \    --stack-name private-lambda-ssl-checker \    --template-body file://template.yaml \    --parameters \        ParameterKey=VpcId,ParameterValue=vpc-0123456789abcdef0 \        ParameterKey=SubnetIds,ParameterValue=\"subnet-0123456789abcdef0,subnet-0fe23456789abcdef1\" \        ParameterKey=RouteTableIds,ParameterValue=\"rtb-0f4a5551c578429b9\" \        ParameterKey=S3BucketName,ParameterValue=my-unique-cert-store-bucket \    --capabilities CAPABILITY_IAM   `

> **Note:** Leave CustomCertificatePem empty if uploading multi-certificate chains or files directly to S3.

### Step 2: Upload Your SSL Inspection Certificate to S3

Upload your firewall root/intermediate CA certificate to the newly created S3 bucket (CertBucketName output):

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # Upload certificate using original filename (no renaming required)  aws s3 cp ZscalerRootCertificate-2048-SHA256-Feb2025.crt s3:///   `

🧪 Testing & Verification
-------------------------

1.  Open the **AWS Lambda Console**.
    
2.  Select the function named URLStatusChecker (do not select S3ProvisionerFunction).
    
3.  Under the **Test** tab, create a test event with the target URL:
    

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   {    "url": "https://ipinfo.io"  }   `

1.  Click **Test**. Successful execution returns statusCode: 200, the container's private IP, and the parsed response body:
    

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   {    "statusCode": 200,    "url": "https://ipinfo.io",    "privateIp": "10.0.2.145",    "message": "Successfully connected to https://ipinfo.io",    "trustStoreUsed": "/tmp/custom-ca-bundle.pem",    "responseBody": {      "ip": "104.28.194.1",      "hostname": "ipinfo.io",      "city": "New York",      "region": "New York",      "country": "US",      "org": "AS13335 Cloudflare, Inc."    },    "responseHeaders": {      "content-type": "application/json; charset=utf-8",      "date": "Thu, 13 Aug 2026 18:45:00 GMT"    }  }   `

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
    

🔄 In-Place Stack Updates
-------------------------

To update an existing deployment without deleting resources:

1.  Open the **CloudFormation Console** -> Select stack -> Click **Update stack** -> **Make a direct update**.
    
2.  Select **Replace current template** and upload the updated template.yaml.
    
3.  Proceed through parameter review and execute the change set.
    

Alternatively via CLI:

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   aws cloudformation update-stack \    --stack-name private-lambda-ssl-checker \    --template-body file://template.yaml \    --use-previous-template-parameters \    --capabilities CAPABILITY_IAM   `

❓ Troubleshooting
-----------------

Issue / Error

Cause

Resolution

KeyError: 'StackId' during testing

Test event was run against S3ProvisionerFunction instead of URLStatusChecker.

Ensure you select the URLStatusChecker function in the Lambda console.

\[X509\] PEM lib (\_ssl.c:4176)

Certificate contained UTF-8 BOM headers or invalid PEM formatting.

Re-deploy using CloudFormation Template v1.0.2+ which includes utf-8-sig BOM stripping.

403 AccessDenied on Stack Deletion

S3 Bucket Policy explicit Deny rule blocked policy deletion.

Click **Delete Stack** again, select **Retain Resources** for CertBucketPolicy & CertBucket, then delete the bucket policy via CLI.

Resource name conflict

Bucket name specified in parameters already exists globally.

Supply a unique bucket name or leave S3BucketName blank to auto-generate.

🏷️ Tagging & Compliance
------------------------

All stack resources include standardized resource tags:

*   Name: URLStatusChecker
    
*   ManagedBy: CloudFormation
    
*   SecurityInspection: Enabled
    

Additional stack-level tags configured during deployment will automatically propagate to all underlying resources.
