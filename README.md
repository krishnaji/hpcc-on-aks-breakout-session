
Deploy AKS cluster, use deploy-aks-cluster.sh script

Clone the HPCC Helm Charts
```git clone https://github.com/hpcc-systems/helm-chart ```

Update the values.yaml,sample is provided in this repo

Deploy HPCC Clusrer with ```helm install mycluster ./hpcc ```

Wait for ECLWatch IP , ```kubectl get svc ```

Visit ECLWatch IP and then from the playground execute terasort-prep.ecl and terasort.ecl




