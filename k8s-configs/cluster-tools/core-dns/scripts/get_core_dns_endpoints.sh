    #!/bin/sh

    IPFILE="/config/core-dns-endpoints"
    RECORDSET="core-dns-endpoints.${TENANT_DOMAIN}"

    echo "NO UPDATE"> $IPFILE
   
    # Install kubectl
    echo "Installing kubectl"
    curl https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl

    chmod +x /usr/local/bin/kubectl


    CURRENT_ENDPOINT=$(kubectl get endpoints  -n kube-system kube-dns  -o jsonpath='{.subsets[*].addresses[*].ip}')

    echo "CURRENT_ENDPOINT: $CURRENT_ENDPOINT"
    RECORDSET_ENDPOINT=$(nslookup -type=txt $RECORDSET | grep $RECORDSET | cut -d= -f2 | tr -d '"')

    echo "RECORDSET_ENDPOINT: $RECORDSET_ENDPOINT"
    for IP in $CURRENT_ENDPOINT
    do
        if ! echo "$RECORDSET_ENDPOINT" | grep -q $IP; then
          echo $CURRENT_ENDPOINT> $IPFILE
        fi
    done

    cat $IPFILE
    
    echo "Config file successfully updated"
    exit 0

