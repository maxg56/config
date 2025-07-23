#!/bin/bash

# Ce script doit être exécuté depuis un terminal kitty
# Il récupère le working directory du terminal courant et ouvre un nouvel onglet dedans

kitty @ launch --cwd=current
