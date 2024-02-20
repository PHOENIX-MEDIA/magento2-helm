# Magento2 Helm Chart

Easily deploy Magento2 in Kubernetes including MySQL, Elasticsearch, Redis, RabbitMQ and Varnish.
The project includes best-of-breed charts from Bitnami, Elasticsearch and others to give maximum flexibility for deploying and
configuring the services.

The chart has been battle tested in Magento2 OpenSource and Adobe Commerce production environments. The bundled `values.yaml` provides basic settings, which should be adjusted before deployment.

## TL;DR

Install via CLI:

```bash
helm install --create-namespace -n magento2-demo magento2 oci://registry-1.docker.io/phoenixmedia/magento --version 2.7.0
```

Add as dependency to existing chart:

```yaml
apiVersion: v2
name: my-project-chart
...
dependencies:
  - name: magento
    version: 2.7.0
    repository: oci://registry-1.docker.io/phoenixmedia
```

## Magento2 base image
The chart references [PHOENIX MEDIA's](https://www.phoenix-media.eu) Magento2 Docker image. It consists of an
[Alpine nginx+PHP8.2 base image](https://github.com/PHOENIX-MEDIA/docker-nginx-php), [Magento OpenSource 2.4.6-p4 source code](https://github.com/magento/magento2)
and a few Composer packages to add [build+deploy scripts](https://github.com/PHOENIX-MEDIA/magento2-cloud-build). The image is available on [DockerHub](https://hub.docker.com/r/phoenixmedia/magento2)
and the source code including Github Action is available in the [magento2-build repository](https://github.com/PHOENIX-MEDIA/magento2-build).

For more information checkout the article [Running Magento2 in Kubernetes —
Part 2: Building the Docker Image](https://medium.com/@bjoern.kraus/running-magento2-in-kubernetes-part-2-building-the-docker-image-8516c0ed7d48).

## Magento ECE-Tools
> ECE-Tools is a set of scripts and tools designed to manage and deploy Cloud projects.

Using [ECE-Tools](https://github.com/magento/ece-tools/) for building and deploying the Docker image reduces the amount
of custom scripts and also gives great flexibility to adjust process as needed.
It is recommended to get familiar with its [build and deploy mechanisms](https://devdocs.magento.com/cloud/project/magento-env-yaml.html).

It is required to review and adjust the [Magento Cloud environment variables](https://devdocs.magento.com/cloud/env/variables-cloud.html)
for the `magento` and `cronjob` deployment in the `values.yaml`:
- MAGENTO_CLOUD_ROUTES
- MAGENTO_CLOUD_RELATIONSHIPS
- MAGENTO_CLOUD_VARIABLES

Their values are simply base64 encoded JSON objects. To decode them either run `echo "<value>" | base64 -d` or use an
[online decoder](https://www.base64decode.org/) (beware when using sensitive data).

> **_Note:_** It is best practice to maintain sensitive values in a [Kubernetes Secret](https://kubernetes.io/docs/concepts/configuration/secret/) instead of keeping them in the `values.yaml`.

### Updating domains MAGENTO_CLOUD_* variables and values files
The values*.yaml files contain domain specific configurations. You will need to update a few lines the environment
variables of the magento, cronjob and xdebug (optional) workloads as well as in the ingress section:

```
secrets:
  credentials:
    data:
      MAGENTO_CLOUD_ROUTES: <base64-encoded-string-containing-your-domain>
      MAGENTO_CLOUD_ROUTES: <base64-encoded-string-containing-your-domain>

ingress:
  hosts:
    - name: <your-domain>
```


## Ingress

Before enabling the ingress make sure to configure `host.name` and the TLS certificate properly. When having
[cert-manager](https://cert-manager.io/docs/) installed set `ingress.certManager: true` to automatically generate a
certificate for the application.

If you prefer to skip Varnish for certain routes simply configure additional paths:

```
    paths:
    - path: "/"
      serviceName: varnish
      servicePort: 80
    - path: "/pub/media"
      serviceName: magento
      servicePort: 80
```

In case you want to protect the Magento backend by IP or BasicAuth we recommend to duplicate the `templates/ingress.yaml`
(e.g. to your Helm project root) and configure a second Ingress with proper annotations.

## Secrets

It is recommended to store sensitive information in a Kubernetes Secret (default name "general-secrets"). The Helm
Chart supports multiple ways to deploy secrets:

### Secrets in value file
Like in the default `values.yaml` sensitive information can be set directly in the YAML structure:

```
secrets:
  credentials:
    data:
      mariadb-password: topSecret
```

While this is okay for testing, it is not recommended to use this in production environments.

### Set sensitive information via CLI
In many CI/CD pipelines credentials are accessible by environment variables which can be easily passed via CLI:

```
helm install --set secrets.credentials.data.mariadb-password=$MYSQL_PASSWORD -f values.yaml magento2 .
```

### External Secrets Operator (ESO)
Credentials could be safely stored in a Vault. The [ESO](https://external-secrets.io/) can read credentials form all
major Vault providers, transform them and save them in a Kubernetes Secret. Even more it can automatically refresh them.

Support for ESO can be enabled simply by setting `secrets.externalSecrets.enabled=true`. The template for the SecretStore
allows flexible configuration of the preferred secret provider.

The `value.yaml` provides an example configuration for [Hashicorp Vault](https://external-secrets.io/v0.8.1/provider/hashicorp-vault/).
It also contains an ExternalSecret example for data and templates definition.
For more information see the ESO [documentation](https://external-secrets.io/v0.8.1/api/components/). 


## Persistence

For the media and var folder Magento usually requires an NFS share. Depending on the Kubernetes environment files shares
are available by referencing the correct storageClass.

In the `values.yaml` the `persistence` section and adjust it:

```
persistence:
  enabled: true
  name: magento-data
  #existingClaim:
  accessMode: ReadWriteMany
  size: 10Gi
  storageClassName: "files"
```

Existing [PVCs](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims) can be also referenced
by using `existingClaim`.


## SMTP server
supervisord starts a simple Postfix MTA included in the [Alpine base image](https://github.com/PHOENIX-MEDIA/docker-nginx-php).
However, you should configure a mail relay which accepts mails for your Magento instance and is eligible to send emails for
the configured store email addresses.

Make sure to configure it for the `magento` and `cronjob` deployment:

```
    env:
    - name: RELAYHOST
      value: my.relayhost.com
    - name: SMTP_USE_TLS
      value: "true"
```


## Sample data
For fresh installations it is possible to install Magento's sample data. This requires [Magento Marketplace](https://devdocs.magento.com/guides/v2.4/install-gde/prereq/connect-auth.html)
authentication keys to be configured. They can be set in the environment variables of the cronjob deployment:

```
  env:
    - name: ADD_SAMPLE_DATA
      value: "true"
    - name: COMPOSER_AUTH
      value: |-
        {
          "http-basic": {
            "repo.magento.com": {
              "username": "<public key>",
              "password": "<private key>"
            }
          }
        }

```

## Xdebug
Debugging in a remote environment can help to bring down resolution time for complex issues. Since Xdebug has to
establish a TCP connection to the IDE, the network setup can become complex.

While this Helm chart won't solve the complexity of setting up a VPN and maybe [DBGp proxy](https://xdebug.org/docs/dbgpProxy)
it deploys an additional container which has Xdebug enabled. In order to route traffic to this Xdebug-enabled Magento container
you have to adjust the Varnish VCL prepared in the `values.yaml`:

```
      # whitelist your developer IPs
      acl xdebug-users {
          "192.168.0.0/24";
      }

      # uncommend these lines
      # use xdebug backend
      #    if (req.http.cookie ~ "XDEBUG_SESSION=" && std.ip(req.http.X-Real-IP, "0.0.0.0") ~ xdebug-users) {
      #        set req.backend_hint = magento_director.backend("xdebug");
      #        return (pass);
      #    }
```

For any request from the whitelisted networks which has the XDEBUG_SESSION request cookie (we use [Xdebug Chrome Extension](https://chrome.google.com/webstore/detail/xdebug-chrome-extension/oiofkammbajfehgpleginfomeppgnglk))
the request will be sent to the `xdebug` pod instead of the normal `magento` pods.

In addition, the settings for the `xdebug` workload have to be adjusted in the `values.yaml`:

```
xdebug:
  enabled: true
  reuseMagentoEnvs: true
  env:
    - name: XDEBUG_INSTALL
      value: "true"
    - name: XDEBUG_REMOTE_HOST
      value: "dbgp-proxy"
```

> **_Caution:_** Running Xdebug in a public environment can be a security issue. Enable this functionality at your own risk.

## imgproxy support
[imgproxy](https://imgproxy.net/) instantly resizes images and delivers it in an optimal format. This offloads resources
from the Magento pod and delivers images faster in PNG/WebP without additional effort.

To enable imgproxy in your deployment set `imgproxy.enabled: true` in your values file. Varnish will detect media image request
and will forward the request to imgproxy if available. The response will get cached response on a disk cache. For details check the
modified VCL in `values.yaml`. The relevant sections can be found by search for `x-img` in the VCL.

Resizing of product images happens on-the-fly once you enable the configuration in Magento the [URL format](https://experienceleague.adobe.com/docs/commerce-operations/configuration-guide/storage/remote-storage/remote-storage-image-resize.html?lang=en#configure-url-format-in-adobe-commerce).
This will append formatting instructions for width and height to the original product image URL. In addition to the clients accept headers
this information is used by imgproxy to deliver the image in the desired resolution.

> In case imgproxy can't serve the image the request will be gracefully forwarded to the Magento pod, which serves the 
configured placeholder image for requests to `media/catalog` and `media/wysiwyg`. The relevant VCL subrouting is `vcl_synth`.


## Helm deployment
The chart requires [Helm 3.x](https://helm.sh/) and has been tested with 3.9.0.
Make sure to adjust the `values.yaml` before deployment.

The Helm command is straight forward:

`helm upgrade -i --create-namespace -n my-namespace magento .`

Deploying the whole Magento2 stack is complex operation and not unlikely when trying it the first time. We prefer to use
optional `--wait --timeout 15m` parameters in a deployment pipeline to see if the deployment was actually successful.

To deploy Magento to different environments (develop, staging, production) it is recommended to create a `values_*.yaml`
for each environment and tune the resource limits and configuration values of the services.

## Docker Desktop example
The file `values_docker.yaml` will override values inside `values.yaml`. It contains all of the necessary values that would need to change to run the Helm chart in the [Docker Desktop](https://www.docker.com/products/docker-desktop) K8S environment.
The following steps will give a guide on how to achieve that:

### Prerequisites
- Install *Docker Desktop >= 4.10* locally (Tested with 4.10.1) and enable Kubernetes in the settings to start the cluster.
It is also recommended to increase the available resources of Docker Desktop to 4 CPU cores and 8 GB of RAM to ensure a smooth operation. 
Alternatively you may install *kubectl* separately, however that may be a more error-prone approach.
- Clone this repository locally on your computer.

### Step 1
Verify the kubectl context as shown [here](https://docs.docker.com/desktop/kubernetes/#use-the-kubectl-command) or alternatively generate a `kube-config` file which will be used for the Helm deployment. Make sure to generate it in the same folder as the git repo. Quickest way to do so is:

```
kubectl config view --raw > <name-of-your-file>
```

### Step 2
Set up an environment for Helm. It is recommended to use a Docker container to avoid dependency issues:

```
docker run -ti --entrypoint= -v $(pwd):/apps alpine/helm:latest sh
```

When using the native Helm installation bear in mind that the Helm version needs to >= 3.9

### Step 3
Pull the chart dependencies and deploy the Helm chart.

```
helm dependency update #pulls all the other charts that our chart uses
helm upgrade -i --kubeconfig <name-of-your-kubeconfig-flie> -f values_docker.yaml --create-namespace -n <your-namespace> magento .
```

### Step 3.5
Check the progress of the Helm deployment in Kubernetes (*not in your docker container*)

```
kubectl get pods -n <your-namespace> -w
```

### Step 4
After the deployment has fully finished an Ingress-NGINX instance is needed to access Magento store through the browser. Since Docker Desktop ships without a Kubernetes Ingress, [see here](https://kubernetes.io/docs/concepts/services-networking/ingress/), use the following Helm command to deploy it:

```
helm upgrade --kubeconfig kube-config --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace
```

The command above deploys an Ingress-NGINX pod that has access to the `/etc/hosts` file. Make sure to add a mapping for the predefined  Magento domain, *magento.local*, in this file to ensure the domain points to the local K8S cluster. Ingress will then forward the traffic to the Magento instance.

```
echo "127.0.0.1 magento.local" >> /etc/hosts
```

### Step 5
Navigate to `http://magento.local` in your browser and play around with your local Magento installation!

#### Disclaimer
This guide and the `values_docker.yaml` file are configured for the *magento.local* domain. You will need to update a few lines on the said file as shown in [this section](https://github.com/PHOENIX-MEDIA/magento2-helm#updating-domains-magento_cloud_-variables-and-values-files)

## GKE example
The file `values_gke.yaml` will override values inside `values.yaml`. It contains all necessary values to deploy the Helm chart in a GKE K8S environment.

### Prerequisites
- Create a Google account. You can start a free trial at [GKE](https://cloud.google.com/kubernetes-engine). It is recommended to use the built-in terminal since it will include all the necessary dependencies like Helm, kubectl and gcloud. 
- Clone this repository to the machine you decided to use.

### Step 1
Create a new project and make sure it is connected to your billing account [as described here](https://cloud.google.com/resource-manager/docs/creating-managing-projects).

### Step 2
Switch the gcloud context to the newly created project:

```
gcloud config set project <project-id>
```

### Step 3
Enable all necessary API services:

```
gcloud services enable container.googleapis.com
gcloud services enable file.googleapis.com
```

### Step 4
Create new a Kubernetes cluster:

```
gcloud container clusters create <cluster-name> --zone=asia-east1-a --addons=HttpLoadBalancing,GcePersistentDiskCsiDriver,GcpFilestoreCsiDriver --image-type=UBUNTU_CONTAINERD --machine-type=e2-standard-2
```

### Step 5
Create a static IP for the Ingress domain (optional, since an Ingress IP will not change unless you redeploy it) and update the *values_gke.yaml* file:

```
gcloud compute addresses create <adress-name> --global
```

### Step 6
Pull the chart dependencies and deploy the Helm chart:

```
helm dependency update
helm upgrade -i -f values_gke.yaml --create-namespace -n <your-namespace> magento .
```

### Step 7
Wait until all the workloads reached ready state and ensure the DNS resolves the configured domain name to the Ingress IP.
Navigate to `http://<your-domain>` and checkout the new Magento2 instance.

#### Disclaimer
This guide and the `values_gke.yaml` file are configured for the *magento.phoenix-media.rocks* example domain. You will need to update a few lines as described in [this section](https://github.com/PHOENIX-MEDIA/magento2-helm#updating-domains-magento_cloud_-variables-and-values-files).

## Changelog
### [2.7.0] - 2024-02-20
- Allow custom annotations and labels in all resources 
- Add Horizontal Pod Autoscaler (HPA) and Pod Disruption Budget (PDB) for Magento workload
- Add support for sidecars in Magento deployments
- Add extra manifest to declare additional objects
- Updated Magento2 to v2.4.6-p4 with PHP 8.2 support
- Updated Opensearch (default), Varnish and imgproxy charts
- Fixed: Don't deploy xdebug service if not enabled
- Fixed: Don't deploy RBAC for RabbitMQ
- Changed: Removed GKE managed-cert template. Use new extra-manifest instead.
- Added GH action for linting and testing the chart
- Fixed: chart-releaser for automated publishing
- Kubernetes 1.26-1.29 compatibility

### [2.6.1] - 2023-04-28
- Add support for stringData credentials, changed `secrets.credentials` structure (BC break with 2.6.0) 

### [2.6.0] - 2023-04-28
- *Breaking: Moved all credentials to a Kubernetes Secret. See new _secrets_ section in `values.yaml`*
- Added support for [External Secrets Operator](https://external-secrets.io)

### [2.5.0] - 2023-02-20
- Added Opensearch as alternative to Elasticsearch. Set `elasticsearch.enabled: false` and `opensearch.enabled: true` to 
  switch search engines.
- Added imgproxy for dynamic image resizing. See imgproxy section for details.
- Add disk-cache volume for Varnish
- Updated Helm charts and container images for Redis, Varnish and RabbitMQ to meet Adobe Commerce/Magento 2.4.5 System Requirements

### [2.4.4] - 2023-02-20
- Kubernetes 1.25 compatibility
- Updated Elasticsearch chart to 7.17

### [2.4.3] - 2022-08-18
- Added values_gke.yaml file for GKE deployments
- Added template for GKE managed certificates
- Added GKE deployment guide to readme

### [2.4.2] - 2022-08-11
- Use PHOENIX MEDIA's Magento OpenSource 2.4.5 build as base image

### [2.4.1] - 2022-07-21
- Added optional ingressClassName
- Added values_docker.yaml for Docker Desktop deployments
- small adjustments in values.yaml

### [2.4.0] - 2022-06-24
- Use PHOENIX MEDIA's Magento OpenSource 2.4.4 build as base image
- Updated Bitnami charts
- Use Softonic Varnish chart
- Use upstream Varnish version
- Cleaned up values.yaml

### Changelog
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
