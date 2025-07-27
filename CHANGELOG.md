# Changelog

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-03

### 🎉 Version initiale

#### ✨ Ajouté
- **Génération automatique de tests** : Utilise l'IA (OpenAI/Ollama) via langchain.rb pour générer des tests RSpec/Minitest intelligents
- **Surveillance des fichiers** : Détection en temps réel des modifications avec Listen gem
- **Interface CLI complète** : Commandes Thor modernes avec mode interactif
- **Configuration flexible** : Support de multiples providers IA et personnalisation
- **Exécution automatique** : Lance les tests après génération avec feedback immédiat
- **Rapports détaillés** : Analyse de couverture, qualité, tendances avec SimpleCov
- **Contexte métier intelligent** : Interface interactive pour enrichir la génération
- **Amélioration de tests** : Fonctionnalité pour améliorer les tests existants

#### 🔧 Modules principaux
- `Configuration` : Gestion centralisée des paramètres et détection automatique des frameworks
- `FileWatcher` : Surveillance intelligente avec filtres et détection de types de fichiers
- `AIGenerator` : Génération IA avec prompts optimisés par type de fichier
- `TestRunner` : Exécution avec support RSpec/Minitest et analyse des résultats
- `Reporter` : Rapports HTML/JSON avec métriques de qualité et tendances
- `CLI` : Interface complète avec commandes init, watch, generate, test, report, improve

#### 🎮 Commandes CLI disponibles
- `autotest-ia init` : Initialisation du projet avec configuration IA
- `autotest-ia watch` : Surveillance automatique des fichiers
- `autotest-ia generate FILE` : Génération manuelle de tests
- `autotest-ia test` : Exécution des tests avec analyse
- `autotest-ia report TYPE` : Génération de rapports (coverage, quality, trend, full)
- `autotest-ia improve TEST SOURCE` : Amélioration de tests existants
- `autotest-ia config` : Affichage de la configuration
- `autotest-ia interactive` : Mode interactif complet
- `autotest-ia version` : Affichage de la version

#### 🤖 Intégrations IA
- Support **OpenAI** (GPT-3.5, GPT-4) via API
- Support **Ollama** pour modèles locaux (Code Llama, etc.)
- Prompts optimisés par type de fichier (model, controller, service, job, helper, mailer)
- Analyse contextuelle du projet (migrations, routes, associations)

#### 📊 Fonctionnalités de reporting
- Rapport HTML complet avec métriques visuelles
- Analyse de couverture de code avec SimpleCov
- Métriques de qualité (ratio tests/source, taille des fichiers, gros fichiers)
- Analyse de tendances historiques
- Suggestions d'amélioration automatiques
- Export JSON pour intégrations

#### 🔧 Configuration et personnalisation
- Fichier `.autotest_ia.yml` pour configuration projet
- Variables d'environnement pour clés API
- Chemins de surveillance configurables
- Seuils de couverture personnalisables
- Templates de prompts modifiables
- Support RSpec et Minitest

#### 🏗️ Architecture technique
- Architecture modulaire et extensible
- Gestion d'erreurs robuste avec exceptions personnalisées
- Lazy loading des composants pour performance
- Interface uniforme avec langchain.rb
- Tests unitaires complets (à venir)
- Documentation inline complète

#### 📦 Dépendances
- `langchainrb ~> 0.6` : Interface IA unifiée
- `listen ~> 3.8` : Surveillance des fichiers
- `thor ~> 1.2` : Framework CLI
- `tty-prompt ~> 0.23` : Interface interactive
- `tty-spinner ~> 0.9` : Indicateurs de progression
- `colorize ~> 0.8` : Coloration de la sortie

#### 🔧 Dépendances de développement
- `rspec ~> 3.0` : Framework de test principal
- `guard ~> 2.18` : Surveillance pour le développement
- `factory_bot ~> 6.2` : Génération de données de test
- `faker ~> 3.0` : Données factices
- `shoulda-matchers ~> 5.0` : Matchers RSpec pour Rails
- `simplecov ~> 0.22` : Couverture de code
- `vcr ~> 6.1` : Enregistrement des requêtes HTTP
- `webmock ~> 3.18` : Mock des requêtes web
- `email_spec ~> 2.2` : Tests d'emails
- `database_cleaner-active_record ~> 2.1` : Nettoyage de base de données

### 📋 Notes de version

Cette première version pose les fondations complètes d'autotest-ia avec :

1. **Architecture robuste** : Modules découplés et extensibles
2. **Expérience utilisateur fluide** : CLI intuitive avec mode interactif
3. **Intégration IA avancée** : Support de multiples providers avec contexte intelligent
4. **Automatisation complète** : De la détection à l'exécution des tests
5. **Reporting avancé** : Analyses et métriques détaillées

### 🚀 Prochaines versions prévues

- **v0.2.0** : Tests unitaires complets et CI/CD
- **v0.3.0** : Support de providers IA supplémentaires (Anthropic, Google)
- **v0.4.0** : Interface web pour configuration et monitoring
- **v0.5.0** : Intégrations Git hooks et systèmes de build
- **v1.0.0** : Version stable avec toutes les fonctionnalités
