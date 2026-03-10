# ArgoCD

## Installing

kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f kube
