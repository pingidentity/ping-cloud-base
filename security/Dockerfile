FROM docker:24-cli

RUN apk add curl bash gcompat && \
  curl -O "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" && \
  chmod +x ./install_kustomize.sh && \
  ./install_kustomize.sh 3.8.1 && \
  mv kustomize /usr/local/bin/ && \
  chmod u+x /usr/local/bin/kustomize && \
  curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
