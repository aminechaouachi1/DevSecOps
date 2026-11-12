#!/usr/bin/env bash
# Installe Docker + Java 21 + Jenkins sur Ubuntu 22.04 et pre-telecharge les outils de securite.
set -euo pipefail
sudo apt-get update
sudo apt-get install -y docker.io git curl wget fontconfig openjdk-21-jre
sudo systemctl enable --now docker

sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
sudo apt-get update
sudo apt-get install -y jenkins

sudo usermod -aG docker jenkins
sudo usermod -aG docker "$USER"
sudo systemctl restart jenkins

echo ">> Pre-telechargement des images (pour que le pipeline soit rapide)"
for img in semgrep/semgrep:latest ghcr.io/zaproxy/zaproxy:stable aquasec/trivy:latest falcosecurity/falco:0.45.2 python:3.12-slim; do
  sudo docker pull "$img"
done

echo
echo "Jenkins : http://localhost:8080"
echo "Mot de passe initial : $(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
