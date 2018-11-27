@echo off
setlocal enabledelayedexpansion enableextensions

ECHO Welcome to antidote-selfmedicate. Take the red pill, it's more fun!

where /q scp 
IF ERRORLEVEL 1 (
    ECHO Cygwin not found. Please install Cygwin or enable ssh/scp on Windows 10.
    EXIT /B
)

where /q minikube
IF ERRORLEVEL 1 (
    ECHO Minikube not found. Please follow installation instructions at: https://antidoteproject.readthedocs.io/en/latest/building/buildlocal.html
    EXIT /B
) ELSE (
    ECHO WARNING, this will delete any existing minikube cluster.
    PAUSE
)



IF NOT exist %USERPROFILE%/.kube/premselfmedicate_bkp (
    ECHO Backing up existing kubeconfig to %USERPROFILE%/.kube/preminikube_bkp...
    cp %USERPROFILE%/.kube/config %USERPROFILE%/.kube/premselfmedicate_bkp
) ELSE (
    ECHO Existing kubeconfig backup found, not re-copying.
)

ECHO Creating minikube cluster. This can take a few minutes, please be patient...
minikube stop >nul 2>&1
minikube delete >nul 2>&1
minikube start --cpus 4 --memory 8192 --network-plugin=cni --extra-config=kubelet.network-plugin=cni >nul 2>&1

:: Set environment variables
FOR /F "tokens=* USEBACKQ" %%F IN (`minikube ip`) DO (
SET minikube_ip=%%F
)
REM ECHO %minikube_ip%

FOR /F "tokens=* USEBACKQ" %%F IN (`minikube ssh-key`) DO (
SET minikube_ssh-key=%%F
)
REM ECHO %minikube_ssh-key%

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i %minikube_ssh-key% multus-cni.conf docker@%minikube_ip%:/home/docker/multus.conf  >nul 2>&1
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i %minikube_ssh-key% -t docker@%minikube_ip% "sudo cp /home/docker/multus.conf /etc/cni/net.d/1-multus.conf"  >nul 2>&1
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i %minikube_ssh-key% -t docker@%minikube_ip% "sudo systemctl restart localkube"  >nul 2>&1

ECHO About to modify %WINDIR%\system32\drivers\etc\hosts to add record for 'antidote-local'.
SET NEWLINE=^& echo.
FIND /C /I "antidote-local" %WINDIR%\system32\drivers\etc\hosts
IF %ERRORLEVEL% NEQ 0 ECHO %NEWLINE%^%minikube_ip%    antidote-local>>%WINDIR%\System32\drivers\etc\hosts

echo "Uploading platform manifests..."
kubectl create -f weaveinstall.yml >nul 2>&1
kubectl create -f multusinstall.yml >nul 2>&1
kubectl create -f nginx-controller.yaml >nul 2>&1
kubectl create -f syringe.yml >nul 2>&1
kubectl create -f antidote-web.yaml >nul 2>&1

ECHO "Finished! Antidote is being spun up right now. Soon, it will be available at:"
ECHO https://antidote-local:30002/
EXIT /B

