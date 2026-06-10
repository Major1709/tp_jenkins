# Mini Projet Jenkins Docker Kubernetes

Ce projet suit le TP `TP3-Mini_projet_Jenkins_docker_kubernetes.pdf`.

## Structure

```text
tp_jenkins/
  README.md
  jenkins_simple/
    Dockerfile
    docker-compose.yml
    home/
    jenkins_data/
  flask_app/
    .dockerignore
    .gitignore
    Dockerfile
    Jenkinsfile
    app.py
    requirements.txt
    test.py
    kubernetes/
      deployment.yaml
      service.yaml
```

## Partie 1 - Lancer Jenkins avec Docker Compose

Depuis `tp_jenkins/jenkins_simple` :

```powershell
cd jenkins_simple
docker compose build
docker compose up -d
docker compose logs -f jenkins
```

Le conteneur Jenkins utilise une image personnalisee basee sur `jenkins/jenkins:lts-jdk17`.
Elle ajoute Docker CLI pour les tests locaux et les besoins du TP.

## Lancement automatique

Un script PowerShell permet de lancer les etapes principales automatiquement.

Depuis `tp_jenkins` :

```powershell
.\run_all.ps1
```

Ce script fait :

- demarrage de Jenkins avec Docker Compose ;
- installation des dependances Python ;
- execution des tests Flask ;
- build de l'image Docker ;
- demarrage du registry local ;
- tag et push de l'image vers `localhost:4000`.

Pour lancer aussi le deploiement Kubernetes :

```powershell
.\run_all.ps1 -DeployKubernetes
```

Pour ne pas demarrer Jenkins :

```powershell
.\run_all.ps1 -SkipJenkins
```

Pour ne faire que les tests Python sans Docker :

```powershell
.\run_all.ps1 -SkipJenkins -SkipDocker
```

Quand Jenkins affiche le token d'installation, ouvrir :

```text
http://localhost:8080
```

Puis :

1. Coller le token.
2. Installer les plugins recommandes.
3. Creer un utilisateur administrateur.
4. Installer le plugin `Blue Ocean` depuis `Manage Jenkins > Plugins` si besoin.
5. Ouvrir Blue Ocean avec `http://localhost:8080/blue`.

## Partie 2 - Premier pipeline Jenkins

Dans Jenkins :

1. Creer un nouvel item.
2. Choisir `Pipeline`.
3. Nommer le job `hello`.
4. Coller ce script :

```groovy
pipeline {
    agent any
    stages {
        stage("Hello") {
            steps {
                echo 'Hello World'
            }
        }
    }
}
```

5. Lancer le build et lire les logs.

## Partie 3 - Tester l'application Flask localement

Depuis `flask_app` :

```bash
python -m venv venv
```

Sous Windows PowerShell :

```powershell
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
python test.py -v
```

Sous Linux/macOS :

```bash
source venv/bin/activate
pip install -r requirements.txt
python test.py -v
```

## Partie 4 - Construire et tester l'image Docker

Depuis `flask_app` :

```bash
docker build -t flask_hello .
docker run --rm --name flask_hello -p 5000:5000 flask_hello
```

Dans un autre terminal :

```bash
curl http://localhost:5000
curl http://localhost:5000/hello/Simon
```

Pour lancer les tests dans le conteneur :

```bash
docker run --rm flask_hello python test.py -v
```

## Partie 5 - Registry Docker local

Lancer le registry :

```bash
docker run -d --restart=always --name registry-local -p 4000:5000 registry:2
```

Tagger et pousser l'image :

```bash
docker tag flask_hello localhost:4000/flask_hello:latest
docker push localhost:4000/flask_hello:latest
```

Le pipeline Kubernetes pousse l'image vers :

```text
host.docker.internal:4000/pythontest:latest
```

Cette adresse permet aux pods Kubernetes Docker Desktop d'atteindre le registry lance sur la machine hote.

## Partie 6 - Configurer Kubernetes pour Jenkins

Verifier que Kubernetes Docker Desktop fonctionne :

```powershell
kubectl config get-contexts
kubectl config use-context docker-desktop
kubectl get nodes
```

Le cluster utilise chez nous :

```text
https://127.0.0.1:13604
```

Depuis Jenkins, l'URL a mettre dans le Cloud Kubernetes est :

```text
https://host.docker.internal:13604
```

Dans Jenkins :

```text
Manage Jenkins > Clouds > New cloud > Kubernetes
```

Configuration :

```text
Name: kubernetes
Kubernetes URL: https://host.docker.internal:13604
Disable https certificate check: coche
Kubernetes Namespace: default
Credentials: k8s-jenkins-token
Jenkins URL: http://host.docker.internal:8080/
Jenkins tunnel: host.docker.internal:50000
```

Creer le service account Kubernetes pour Jenkins :

```powershell
kubectl create serviceaccount jenkins -n default
kubectl create clusterrolebinding jenkins-cluster-admin --clusterrole=cluster-admin --serviceaccount=default:jenkins
kubectl create token jenkins -n default --duration=8760h
```

Dans Jenkins, ajouter le token :

```text
Manage Jenkins > Credentials > System > Global credentials > Add Credentials
Kind: Secret text
Secret: token genere par kubectl
ID: k8s-jenkins-token
```

## Partie 7 - Jenkinsfile

Le fichier `flask_app/Jenkinsfile` contient trois stages :

1. `Test python`
2. `Build image`
3. `Deploy`

Le pipeline utilise un agent Kubernetes compose de quatre conteneurs :

- `python` pour installer les dependances et lancer les tests ;
- `docker` pour construire et pousser l'image ;
- `dind` pour fournir un Docker daemon interne au pod ;
- `jnlp`, ajoute automatiquement par Jenkins pour connecter l'agent.

Le build Docker utilise :

```text
DOCKER_HOST=tcp://localhost:2375
```

Cette approche evite le montage de `/var/run/docker.sock`, qui ne fonctionne pas correctement avec Docker Desktop Kubernetes dans cette configuration.

## Partie 8 - Deploiement Kubernetes

Depuis `flask_app` :

```bash
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
```

Verifier :

```bash
kubectl get pods
kubectl get svc
```

Si le cluster supporte `NodePort`, l'application est exposee sur :

```text
http://localhost:31000
```

## Partie 9 - Creer le pipeline Jenkins

Dans Jenkins :

```text
New Item > Pipeline
```

Nom :

```text
tp_jenkins
```

Dans la section `Pipeline` :

```text
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/Major1709/tp_jenkins.git
Branch Specifier: */main
Script Path: flask_app/Jenkinsfile
```

Puis :

```text
Save > Build Now
```

Ensuite, Jenkins relance automatiquement le pipeline quand un nouveau commit est pousse sur la branche configuree, car le `Jenkinsfile` contient :

```groovy
triggers {
  pollSCM('* * * * *')
}
```

Pour envoyer un changement vers GitHub :

```bash
git add .
git commit -m "Update Jenkins project documentation"
git push origin main
```

## Partie 10 - Branche feature et TDD

Creer une branche :

```bash
git checkout -b feature1
```

Ajouter un test dans `test.py` :

```python
def test_feature_name(self):
    name = 'Simon'
    rv = self.app.get(f'/feature/{name}')
    self.assertEqual(rv.status, '200 OK')
    self.assertIn(bytearray(name, 'utf-8'), rv.data)
```

Le test echoue tant que la route `/feature/<username>` n'existe pas.

Corriger `app.py` :

```python
@app.route('/feature/<username>')
def feature_user(username):
    return 'Feature %s!\n' % username
```

Relancer :

```bash
python test.py -v
```

## Notes importantes

- Sur Docker Desktop avec Kubernetes, l'adresse `localhost:4000` n'est pas fiable depuis les pods. Utiliser `host.docker.internal:4000`.
- Le pipeline utilise Docker-in-Docker pour builder l'image dans l'agent Kubernetes.
- Le service account `jenkins` est volontairement `cluster-admin` pour simplifier le TP local. En production, il faut limiter strictement les droits.
- Le chart Helm `stable/jenkins` du PDF est ancien. Pour une installation moderne, utiliser le chart officiel maintenu par Jenkins.
- L'image historique `jenkinsci/blueocean` du TP est ancienne et peut echouer pendant l'installation des plugins. Ce projet utilise `jenkins/jenkins:lts-jdk17`, puis Blue Ocean peut etre installe comme plugin.
