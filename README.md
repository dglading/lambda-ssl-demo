Private Lambda Function with S3 & Custom SSL Certificate Trust Store
====================================================================

This architecture deploys a private AWS Lambda function into an **existing VPC and private subnet(s)**. The function connects to user-supplied URLs to check their status and routes egress traffic through a 3rd-party firewall (such as Zscaler or Palo Alto) performing SSL inspection. To trust re-signed certificates from the firewall, the Lambda function auto-discovers and loads custom CA certificates from an S3 bucket into its trust store during cold start.

⚠️ How the Certificate is Added to the Local Trust Store
--------------------------------------------------------

1.  **Auto-Discovery on Cold Start**: When the Lambda execution container boots up (cold start), build\_trust\_store() automatically queries the S3 bucket and detects your uploaded certificate (such as ZscalerRootCertificate-2048-SHA256-Feb2025.crt).
    
2.  **BOM Stripping & Multi-Format Extraction (**extract\_pem\_certificates**)**:
    
    *   Decodes file bytes using utf-8-sig to automatically strip UTF-8 Byte Order Marks (BOM headers) and standardizes line endings (\\r\\n $\\rightarrow$ \\n).
        
    *   Uses regex to extract clean -----BEGIN CERTIFICATE----- ... -----END CERTIFICATE----- ASCII blocks.
        
    *   If no PEM headers are present, it tests for binary DER format and converts it using ssl.DER\_cert\_to\_PEM\_cert().
        
3.  **Bundle Construction**:
    
    *   Reads Amazon Linux's native public root CAs (/etc/pki/tls/certs/ca-bundle.crt).
        
    *   Appends your cleaned Zscaler Root CA certificate block to the system bundle.
        
    *   Writes the combined bundle to /tmp/custom-ca-bundle.pem in local Lambda storage.
        
4.  **Explicit Binding**:
    
    *   Sets environment variables (SSL\_CERT\_FILE, AWS\_CA\_BUNDLE, REQUESTS\_CA\_BUNDLE) to /tmp/custom-ca-bundle.pem.
        
    *   Passes ssl.create\_default\_context(cafile='/tmp/custom-ca-bundle.pem') explicitly to all urllib.request outbound calls.
        

Architecture Overview
---------------------

1.  **Existing VPC & Subnets**: Prompts for an existing VpcId, SubnetIds (private subnets), and RouteTableIds.
    
2.  **S3 Gateway VPC Endpoint**: Created in the target VPC and attached to the selected Route Table(s), allowing private Lambda traffic to reach S3 without crossing the public internet or requiring a NAT Gateway.
    
3.  **Private S3 Bucket**: Block Public Access enabled, SSE-S3 encrypted, and restricted via Bucket Policy to requests originating from the S3 VPC Endpoint or authorized IAM principals in your AWS account (enabling AWS Console browsing).
    
4.  **Lambda Execution Environment**:
    
    *   Deployed strictly inside the user-selected private subnets (ENI attached).
        
    *   Cold-start auto-discovery script fetches bootstrap.sh and any custom CA certificate (.crt, .pem, or .cer) from S3 and constructs /tmp/custom-ca-bundle.pem.
        
    *   Automatically handles UTF-8 BOM headers, ASCII PEM, and binary DER certificate formats.
        
    *   Explicitly binds the trust store to urllib.request SSL context calls.
        
    *   Reads and parses HTTP response content (JSON/text) and embeds it under responseBody in the output payload.
        
    *   Captures and reports the function container's private IPv4 address (privateIp) dynamically.
