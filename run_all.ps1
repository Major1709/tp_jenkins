param(
    [switch]$SkipJenkins,
    [switch]$SkipDocker,
    [switch]$DeployKubernetes
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$JenkinsDir = Join-Path $Root "jenkins_simple"
$AppDir = Join-Path $Root "flask_app"

function Step($Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Ensure-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Commande introuvable: $Name"
    }
}

Ensure-Command "python"
Ensure-Command "docker"

if (-not $SkipJenkins) {
    Step "Demarrage de Jenkins avec Docker Compose"
    Push-Location $JenkinsDir
    docker compose up -d
    Pop-Location

    Write-Host "Jenkins: http://localhost:8080"
    Write-Host "Blue Ocean: http://localhost:8080/blue"
    Write-Host "Pour voir le token initial: docker compose logs -f jenkins"
}

Step "Installation des dependances Python"
Push-Location $AppDir
python -m pip install -r requirements.txt

Step "Execution des tests Flask"
python test.py -v

if (-not $SkipDocker) {
    Step "Build de l'image Docker"
    docker build --progress=plain -t flask_hello .

    Step "Demarrage du registry Docker local"
    $Registry = docker ps -a --filter "name=registry-local" --format "{{.Names}}"
    if ($Registry -eq "registry-local") {
        docker start registry-local | Out-Null
    } else {
        docker run -d --restart=always --name registry-local -p 4000:5000 registry:2 | Out-Null
    }

    Step "Tag et push de l'image vers le registry local"
    docker tag flask_hello localhost:4000/flask_hello:latest
    docker tag flask_hello localhost:4000/pythontest:latest
    docker push localhost:4000/flask_hello:latest
    docker push localhost:4000/pythontest:latest
}

if ($DeployKubernetes) {
    Ensure-Command "kubectl"

    Step "Deploiement Kubernetes"
    kubectl apply -f .\kubernetes\deployment.yaml
    kubectl apply -f .\kubernetes\service.yaml
    kubectl get pods
    kubectl get svc
}

Pop-Location

Step "Termine"
Write-Host "Application Flask locale apres deploiement Kubernetes: http://localhost:31000"
Write-Host "Dossier application a pousser sur GitHub: $AppDir"
