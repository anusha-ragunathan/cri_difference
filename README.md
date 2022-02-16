# cri_difference

This test reveals unexpected modifications to a directory's permissions made during the container's runtime. Refer to this [Dockerfile](https://github.com/anusha-ragunathan/cri_difference/blob/main/Dockerfile) that specifies a directory, which is symlinked, has it's ownership changed and mounted as a VOLUME during image build time. 
- This image, when run as a container on `dockerd` as runtime (both independent of Kubernetes and as a Kubernetes CRI runtime), retains the directory group and ownership as expected. 
- This image, when run as a container directly on `containerd` as runtime (independent of Kubernetes), retains the directory group and ownership as expected. 
- However, when the image is run as a container in a Kubernetes cluster where `containerd` is the CRI runtime, the group and ownership permissions are unexpected.

Testing was done using:
- Kubernetes 1.20
- containerd 1.4.6
- docker 20.10.8


### Build and push
- Build/tag the image.
```
$ docker build . -t rubegolberg22/critest:latest
[+] Building 1.7s (10/10) FINISHED                                                                                                                                                                                      
 => [internal] load build definition from Dockerfile                                                                                                                                                               0.0s
 => => transferring dockerfile: 37B                                                                                                                                                                                0.0s
 => [internal] load .dockerignore                                                                                                                                                                                  0.0s
 => => transferring context: 2B                                                                                                                                                                                    0.0s
 => [internal] load metadata for docker.io/library/busybox:latest                                                                                                                                                  0.0s
 => CACHED [1/6] FROM docker.io/library/busybox:latest                                                                                                                                                             0.0s
 => [2/6] RUN VERSION="2022-02-08"  && mkdir -p /opt/apache-druid-${VERSION}  && ln -s /opt/apache-druid-${VERSION} /opt/druid                                                                                     0.3s
 => [3/6] RUN addgroup -S -g 1000 druid  && adduser -S -u 1000 -D -H -h /opt/druid -s /bin/sh -g '' -G druid druid                                                                                                 0.4s
 => [4/6] RUN mkdir -p /opt/druid/var                                                                                                                                                                              0.4s
 => [5/6] RUN chown -R druid:druid /opt  && chmod 775 /opt/druid/var                                                                                                                                               0.4s
 => [6/6] WORKDIR /opt/druid                                                                                                                                                                                       0.0s
 => exporting to image                                                                                                                                                                                             0.0s
 => => exporting layers                                                                                                                                                                                            0.0s
 => => writing image sha256:48e65d025d378104e356cc92dfc508457b88321bd001ce670854b82fb7385581                                                                                                                       0.0s
 => => naming to docker.io/rubegolberg22/critest:latest                                                                                                                                                            0.0s

Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them
```

- Push image to docker hub
```
$ docker push rubegolberg22/critest:latest
The push refers to repository [docker.io/rubegolberg22/critest]
5f70bf18a086: Layer already exists 
9df3a66e9850: Pushed 
104c469497a1: Pushed 
66d2106cac27: Pushed 
73763c96f44c: Pushed 
d31505fd5050: Layer already exists 
latest: digest: sha256:1be9d276efafe353d0944e3995c467c158ffc32abab9e428b7c287c5d2282211 size: 1561
```

### Run the image as a container on both runtimes, independent of Kubernetes

- Run a container on `dockerd` using the image. Verify that the directory group:owner permissions are set to `druid` as expected. 
```
$ docker run -it rubegolberg22/critest:latest
/opt/apache-druid-2022-02-08 # ls -als
total 20
     8 drwxr-xr-x    1 druid    druid         4096 Feb  8 22:58 .
     8 drwxr-xr-x    1 druid    druid         4096 Feb  8 22:22 ..
     4 drwxrwxr-x    2 druid    druid         4096 Feb  8 22:58 var
```

- Run a container on `containerd` using the image. Verify that the directory group/ownership is set as expected. 

Using `ctr` as client, run the image directly on containerd.
```
# ctr images pull docker.io/rubegolberg22/critest:latest
docker.io/rubegolberg22/critest:latest:                                           resolved       |++++++++++++++++++++++++++++++++++++++| 
manifest-sha256:1be9d276efafe353d0944e3995c467c158ffc32abab9e428b7c287c5d2282211: done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:83e07366e34625919a8da32831413e0374c051012463a23e5ddfca1c5c4ca449:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:4f4fb700ef54461cfa02571ae0db9a0dc1e0cdb5577484a6d75e68dc38e8acc1:    exists         |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:3ab76c0e26fac1156858df9d105c5cd9958cfcda7092a13010f0fcca18b6d177:    done           |++++++++++++++++++++++++++++++++++++++| 
config-sha256:48e65d025d378104e356cc92dfc508457b88321bd001ce670854b82fb7385581:   done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:a44974475eff63b5d114f2213abd4e9082f6ea1b739f1a31906dd3c4896be7a8:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:009932687766e1520a47aa9de3bfe97ffdb1b6cad0b08d5078bad60329f13f19:    exists         |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:8b154b5516e65d11e493e5f4e4c13a9e18ab536ccdc9cdcd6edb992671cc7103:    done           |++++++++++++++++++++++++++++++++++++++| 
elapsed: 2.3 s                                                                    total:  2.8 Ki (1.2 KiB/s)                                       
unpacking linux/amd64 sha256:1be9d276efafe353d0944e3995c467c158ffc32abab9e428b7c287c5d2282211...
done
```

```
# ctr run --rm -t docker.io/rubegolberg22/critest:latest sh
/opt/apache-druid-2022-02-08 # ls -als
total 0
     0 drwxr-xr-x    1 druid    druid           17 Feb  8 22:58 .
     0 drwxr-xr-x    1 druid    druid           50 Feb  8 22:22 ..
     0 drwxrwxr-x    1 druid    druid            6 Feb  8 22:58 var
```

### Run the image as a container on a Kubernetes cluster, with both runtimes as the CRI 

- Run the same image as a [Pod](https://github.com/anusha-ragunathan/cri_difference/blob/main/voltest.yaml) on a Kubernetes cluster using `dockerd` as CRI.

```
$ k apply -f voltest.yaml 
pod/vol-test created
```

```
$ k exec -it vol-test -- sh
/opt/apache-druid-2022-02-08 # ls -als
total 0
     0 drwxr-xr-x    1 druid    druid           17 Feb  8 22:58 .
     0 drwxr-xr-x    1 druid    druid           50 Feb  8 22:22 ..
     0 drwxrwxr-x    2 druid    druid            6 Feb  8 22:58 var
```


- Run the same image as a [Pod](https://github.com/anusha-ragunathan/cri_difference/blob/main/voltest.yaml) on a Kubernetes cluster using `containerd` as CRI.

```
$ k apply -f voltest.yaml 
pod/vol-test created
```

```
$ k exec -it vol-test -- sh
/opt/apache-druid-2022-02-08 # ls -als
total 0
     0 drwxr-xr-x    1 druid    druid           17 Feb  8 22:58 .
     0 drwxr-xr-x    1 druid    druid           50 Feb  8 22:22 ..
     0 drwxr-xr-x    2 root     root             6 Feb 16 02:31 var  <=== unexpected group:owner change (unexpected root:root vs expected druid:druid ) & umask change (unexpected 755 vs expected 775)
```

