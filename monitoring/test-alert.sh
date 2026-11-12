#!/bin/bash
# Simule une panne de la prod : l'alerte part par mail en ~1 minute, puis la prod est relancee
docker stop devsecops-prod
echo "Prod arretee. Attente 100 s (alerte Prometheus -> Alertmanager -> mail)..."
sleep 100
docker start devsecops-prod
echo "Prod relancee. Un mail RESOLVED arrive ensuite."
