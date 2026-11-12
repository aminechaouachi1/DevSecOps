# Pipeline DevSecOps minimal (Jenkins + Docker)

| Phase | Outil | Role | Rapport |
|---|---|---|---|
| 1 Development | Semgrep | SAST : analyse du code source | reports/semgrep.json |
| 2 Acceptance | OWASP ZAP | DAST : scan de l'app qui tourne (staging) | reports/zap.html |
| 3 Production | Trivy | scan de l'image Docker, puis deploiement | reports/trivy.json |
| 4 Operations | Falco | detection d'intrusion en runtime | reports/falco.log |

Flux : Semgrep -> build -> ZAP sur staging -> Trivy -> deploiement prod (port 8081) -> Falco surveille la prod.

## Installation (Ubuntu 22.04)
    ./setup-ubuntu.sh          # Docker + Java 21 + Jenkins + images des outils
    # puis se reconnecter (groupe docker)

## Depot Git
    git init && git add . && git commit -m "devsecops demo" && git branch -M main
    # creer un depot PUBLIC sur GitHub, puis :
    git remote add origin https://github.com/<user>/<repo>.git && git push -u origin main

## Jenkins (http://localhost:8080)
1. Mot de passe initial affiche par setup-ubuntu.sh, "Install suggested plugins".
2. New Item > Pipeline > Pipeline script from SCM > Git > URL du depot, branche `*/main`, Script Path `Jenkinsfile`.
3. Build with Parameters (ENFORCE=false) : le pipeline passe et produit les rapports (onglet Artifacts / Stage View).
4. Relancer avec ENFORCE=true : le pipeline echoue si Semgrep/Trivy trouvent des failles (quality gate).

Verifier la prod : `curl http://localhost:8081/health`

## Remarques
- L'app contient une faiblesse volontaire (MD5 dans /hash) pour que Semgrep ait quelque chose a signaler.
- Falco a besoin d'un noyau avec eBPF (Ubuntu 22.04 : OK). S'il ne demarre pas, le stage passe en UNSTABLE sans casser le build.
