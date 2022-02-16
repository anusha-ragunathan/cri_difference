# cri_difference

This test reveals unexpected changes to directory permissions at container runtime. A Dockerfile specifies a directory, which is symlinked, ownership changed and mounted as a VOLUME during image build time. 
- This image, when run as a container on `dockerd` as runtime (both directly or as a Kubernetes CRI), retains the directory group and ownership as expected. 
- This image, when run as a container directly on `containerd` as runtime, retains the directory group and ownership as expected. 
- However, when the image is run as a container on `containerd` as runtime which is part of a Kubernetes cluster, the group and ownership permissions are unexpected.


Testing was done using:
- Kubernetes 1.20
- containerd 1.4.6
- docker 20.10.8

1. Build the Dockerfile and push image to docker hub.

```
$ docker push rubegolberg22/critest:latest
The push refers to repository [docker.io/rubegolberg22/critest]
5f70bf18a086: Pushed 
12bfa0134feb: Pushed 
ef2c6e6005f7: Pushed 
12f402faa6a2: Pushed 
f58f747c1987: Pushed 
d31505fd5050: Pushed 
latest: digest: sha256:00420c7b8c21bf2e81637c164432f38414f27af7028b670f19b23f595df1855f size: 1561
```

2. Run the image as a container on dockerd. Verify that the group:owner permissions are set as expected.
 
```
$ docker run -it rubegolberg22/critest:latest
/opt/apache-druid-2022-02-08 # ls -als
total 20
     8 drwxr-xr-x    1 druid    druid         4096 Feb  8 22:58 .
     8 drwxr-xr-x    1 druid    druid         4096 Feb  8 22:22 ..
     4 drwxrwxr-x    2 druid    druid         4096 Feb  8 22:58 var
```

3. Using `ctr` as client, run the image directly on containerd. Notice that the group:owner permissions are 'druid'.

```
# ctr images pull docker.io/rubegolberg22/critest:latest
docker.io/rubegolberg22/critest:latest:                                           resolved       |++++++++++++++++++++++++++++++++++++++| 
manifest-sha256:00420c7b8c21bf2e81637c164432f38414f27af7028b670f19b23f595df1855f: done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:4f4fb700ef54461cfa02571ae0db9a0dc1e0cdb5577484a6d75e68dc38e8acc1:    done           |++++++++++++++++++++++++++++++++++++++| 
config-sha256:a94f6ebb43ea56b7427d43c1bcd93f7ad24a5c8cafbb8f52fa74b01a001e2da7:   done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:009932687766e1520a47aa9de3bfe97ffdb1b6cad0b08d5078bad60329f13f19:    exists         |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:1d659f57b71f15c33edde8f4553391623de0d29349d8aa0bd62edf7b06bb88e7:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:ed26635cf537bf798606b256b23e97b195166b39a42e00abc9308fc959700f4a:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:84baca17c1842f8a45a23e3c134e583681aa256eefa73feefa619958105438be:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:7b1d92b04b93005d7bc33b479a7a8393370a4d263dc42c5592cb886ba52566e3:    done           |++++++++++++++++++++++++++++++++++++++| 
elapsed: 2.3 s                                                                    total:  4.1 Ki (1.8 KiB/s)                                       
unpacking linux/amd64 sha256:00420c7b8c21bf2e81637c164432f38414f27af7028b670f19b23f595df1855f...
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

4. Now, run the same image as a Pod on a Kubernetes cluster using containerd as CRI.

cat voltest.yaml
```
apiVersion: v1
kind: Pod
metadata:
 name: vol-test
 labels:
   app: vol-test
spec:
 containers:
 - image: docker.io/rubegolberg22/critest:latest
   command: ["/bin/sh", "-ec", "while :; do echo '.'; sleep 5 ; done"]
   name: vol-test
   imagePullPolicy: Always
 restartPolicy: Never
 terminationGracePeriodSeconds: 3
```

```
$ k exec -it vol-test -- sh
/opt/apache-druid-2022-02-08 # ls -als
total 0
     0 drwxr-xr-x    1 druid    druid           17 Feb  8 22:58 .
     0 drwxr-xr-x    1 druid    druid           50 Feb  8 22:22 ..
     0 drwxr-xr-x    2 root     root             6 Feb 16 02:31 var
```

