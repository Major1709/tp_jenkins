# Mini Projet Jenkins Docker Kubernetes

Ce projet suit le TP `TP3-Mini_projet_Jenkins_docker_kubernetes.pdf`.

## Structure

```text
tp_jenkins/
  README.md
  jenkins_simple/
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

Depuis ce dossier :

```bash
cd jenkins_simple
docker compose up -d
docker compose logs -f jenkins
```

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

## Partie 6 - Jenkinsfile

Le fichier `flask_app/Jenkinsfile` contient trois stages :

1. `Test python`
2. `Build image`
3. `Deploy`

Dans cette version Docker Compose, Jenkins utilise `agent any`.
Les tests sont lances dans un conteneur `python:3.11-slim` avec Docker.
Le stage `Deploy` applique les manifests Kubernetes seulement si `kubectl` est disponible dans l'environnement Jenkins.

## Partie 7 - Deploiement Kubernetes

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

## Partie 8 - Branche feature et TDD

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

- Sur Docker Desktop avec Kubernetes, l'adresse `localhost:4000` peut ne pas etre accessible depuis tous les pods selon la configuration du cluster.
- Monter `/var/run/docker.sock` donne au conteneur Jenkins un acces tres puissant au Docker de l'hote. C'est acceptable pour un TP local, mais pas recommande en production.
- Le chart Helm `stable/jenkins` du PDF est ancien. Pour une installation moderne, utiliser le chart officiel maintenu par Jenkins.
- L'image historique `jenkinsci/blueocean` du TP est ancienne et peut echouer pendant l'installation des plugins. Ce projet utilise `jenkins/jenkins:lts-jdk17`, puis Blue Ocean peut etre installe comme plugin.
