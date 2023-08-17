# Nginx ingress controller v1.8.0 configuration 

The NGINX ingress controller has additional configuration options that can be customized and configured to create a more dynamic application. This can be done in two ways:

Annotations: this option can be used if you want a specific configuration for a particular ingress rule.
ConfigMap: this option can be used when setting global configurations for the NGINX ingress controller.

Note: annotations take precedence over a ConfigMap.

## Timeout Settings
`proxy-connect-timeout` defines the timeout for establishing a connection with a proxied server. The default value is 60 seconds, and the timeout typically cannot exceed 75 seconds.
[proxy_connect_timeout](https://nginx.org/en/docs/http/ngx_http_proxy_module.html?_gl=1*u39h3g*_ga*MTEyNzEyMTQ0MS4xNjc0MjQ2NjM4*_ga_4RQQZ3WGE9*MTY3NDQ5NDIwOS4zLjEuMTY3NDQ5NDUyNy42MC4wLjA.#proxy_connect_timeout)

`proxy-send-timeout` will set a timeout for transmitting a request to the proxied server. The timeout is set only between two successive write operations, not for transmitting the whole request. According to NGINX ingress documentation, the connection is closed if the proxied server does not receive anything within this time.
[proxy_send_timeout](https://nginx.org/en/docs/http/ngx_http_proxy_module.html?_gl=1*u39h3g*_ga*MTEyNzEyMTQ0MS4xNjc0MjQ2NjM4*_ga_4RQQZ3WGE9*MTY3NDQ5NDIwOS4zLjEuMTY3NDQ5NDUyNy42MC4wLjA.#proxy_send_timeout)


Example Settings:
```sh
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  annotations:
    nginx.org/proxy-connect-timeout: "30s"
    nginx.org/proxy-send-timeout: "20s"
```

## Access Log

NGINX writes the logs in a file once the request has been processed. They are enabled by default in NGINX, if you want to disable them for a given ingress. To do this, use this annotation:

```sh
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  annotations:
     nginx.ingress.kubernetes.io/enable-access-log: "false"
spec:
```

## keep-alive-requests 

Sets the maximum number of requests that can be served through one keep-alive connection. After the maximum number of requests are made, the connection is closed.
[keep-alive-requests](https://nginx.org/en/docs/http/ngx_http_core_module.html#keepalive_requests)

## upstream-keepalive-timeout

Sets a timeout during which an idle keepalive connection to an upstream server will stay open.

[keepalive_timeout](https://nginx.org/en/docs/http/ngx_http_upstream_module.html#keepalive_timeout)

## max-worker-connections

Sets the maximum number of simultaneous connections that each worker process can open. 0 will use the value of max-worker-open-files. default: 16384

!!! tip Using 0 in scenarios of high load improves performance at the cost of increasing RAM utilization (even on idle).

[worker_connections number](https://nginx.org/en/docs/ngx_core_module.html#worker_connections)

## worker-processes

Sets the number of worker processes. The default of "auto" means the number of available CPU cores.

[worker_processes](https://nginx.org/en/docs/ngx_core_module.html#worker_processes)


# References

[NGINX Configuration](https://github.com/kubernetes/ingress-nginx/blob/controller-v1.8.0/docs/user-guide/nginx-configuration/index.md)

