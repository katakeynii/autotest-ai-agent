# 🤖 Autotest IA

[![Coverage Status](https://img.shields.io/badge/coverage-91.04%25-green.svg)](coverage/index.html)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.txt)
[![Ruby Version](https://img.shields.io/badge/Ruby-3.0+-red.svg)](https://www.ruby-lang.org/)
[![Made in Senegal](https://img.shields.io/badge/Made%20in-Senegal%20🇸🇳-green.svg)](https://www.senegal.sn/)

[![LangChain](https://img.shields.io/badge/LangChain-0.19+-blue.svg)](https://rubygems.org/gems/langchainrb)
[![Listen](https://img.shields.io/badge/Listen-3.9+-orange.svg)](https://rubygems.org/gems/listen)
[![Thor](https://img.shields.io/badge/Thor-1.4+-red.svg)](https://rubygems.org/gems/thor)
[![TTY::Prompt](https://img.shields.io/badge/TTY::Prompt-0.23+-purple.svg)](https://rubygems.org/gems/tty-prompt)

**Automatisez la génération, mise à jour et exécution de tests Rails avec l'Intelligence Artificielle**

`autotest-ia` est un gem innovant qui révolutionne l'écriture de tests dans vos applications Rails en exploitant la puissance de l'IA pour générer automatiquement des tests pertinents, maintenir la couverture de code et améliorer la qualité de vos projets.

## ✨ Fonctionnalités

🔥 **Génération automatique de tests** : L'IA analyse votre code et génère des tests RSpec/Minitest intelligents
🔍 **Surveillance en temps réel** : Détecte automatiquement les changements de fichiers et génère les tests correspondants
🧠 **Context métier intelligent** : Interface interactive pour enrichir le contexte métier et générer des tests plus pertinents
📊 **Rapports détaillés** : Analyse de couverture, qualité du code, tendances et suggestions d'amélioration
⚡ **Exécution automatique** : Lance les tests après génération avec feedback immédiat
🔧 **Configuration flexible** : Support OpenAI, Ollama, personnalisation des prompts et frameworks
🎯 **Interface CLI moderne** : Commandes intuitives avec mode interactif complet

## 🇸🇳 À propos

Ce projet a été développé au **Sénégal** 🇸🇳 avec pour mission d'améliorer la productivité des développeurs Ruby/Rails en automatisant l'écriture de tests grâce à l'intelligence artificielle.

**Auteur** : Mohamed Camara GUEYE - Développeur passionné basé au Sénégal  
**Vision** : Démocratiser l'utilisation de l'IA dans le développement logiciel pour la communauté africaine et mondiale


## 🚀 Installation

Ajoutez cette ligne au `Gemfile` de votre application :

```ruby
gem 'autotest-ia'
```

Puis exécutez :

```bash
$ bundle install
```

Ou installez directement :

```bash
$ gem install autotest-ia
```

## ⚙️ Configuration initiale

### 1. Initialisation dans votre projet

```bash
$ autotest-ia init
```

Cette commande :
- Détecte ou configure RSpec/Minitest
- Crée le fichier de configuration `.autotest_ia.yml`
- Configure les chemins de surveillance par défaut
- Vérifie la compatibilité du projet

### 2. Configuration de l'IA

#### Pour OpenAI (recommandé)

```bash
export OPENAI_API_KEY="votre-clé-openai"
autotest-ia init --provider openai --model gpt-4
```

#### Pour Ollama (local)

```bash
# Démarrez Ollama localement
ollama serve

# Configurez autotest-ia
autotest-ia init --provider ollama --model codellama
```

### 3. Fichier de configuration

Le fichier `.autotest_ia.yml` permet de personnaliser le comportement :

```yaml
# Configuration autotest-ia
ai_provider: openai
ai_model: gpt-3.5-turbo
interactive_mode: true
auto_run_tests: true
coverage_threshold: 80

# Chemins à surveiller
watch_paths:
  - app/models
  - app/controllers
  - app/jobs
  - app/services
  - app/helpers
  - app/mailers
  - lib

# Chemins à exclure
exclude_paths:
  - tmp
  - log
  - vendor
  - node_modules
  - .git
```

## 🎮 Utilisation

### Mode surveillance automatique

Lancez la surveillance intelligente de vos fichiers :

```bash
$ autotest-ia watch
```

Dès qu'un fichier est modifié, `autotest-ia` :
1. 🔍 Détecte le changement
2. 🧠 Analyse le code avec l'IA
3. 📝 Génère ou met à jour le test correspondant
4. 🧪 Exécute les tests automatiquement
5. 📊 Affiche les résultats et suggestions

### Génération manuelle de tests

Pour un fichier spécifique :

```bash
# Génération simple
$ autotest-ia generate app/models/user.rb

# Avec contexte métier
$ autotest-ia generate app/models/user.rb --context "Modèle utilisateur avec authentification OAuth"

# Mode interactif (recommandé)
$ autotest-ia generate app/models/user.rb --interactive
```

Le mode interactif vous guide pour :
- Préciser le rôle métier du composant
- Définir les règles spécifiques à tester
- Identifier les cas limites importants
- Spécifier les contraintes techniques

### Exécution et analyse des tests

```bash
# Exécuter tous les tests
$ autotest-ia test

# Tests spécifiques
$ autotest-ia test spec/models/user_spec.rb

# Mode surveillance des tests
$ autotest-ia test --watch

# Avec analyse détaillée
$ autotest-ia test --coverage
```

### Rapports et analyses

```bash
# Rapport complet HTML
$ autotest-ia report full

# Analyse de couverture
$ autotest-ia report coverage

# Métriques de qualité
$ autotest-ia report quality

# Tendances (7 derniers jours)
$ autotest-ia report trend --days 7
```

### Amélioration de tests existants

```bash
# Améliorer un test existant
$ autotest-ia improve spec/models/user_spec.rb app/models/user.rb

# Avec notes spécifiques
$ autotest-ia improve spec/models/user_spec.rb app/models/user.rb --notes "Ajouter tests pour la validation email"
```

### Mode interactif complet

Pour une expérience guidée :

```bash
$ autotest-ia interactive
```

## 🔧 Commandes CLI complètes

| Commande              | Description              | Options principales                      |
| --------------------- | ------------------------ | ---------------------------------------- |
| `init`                | Initialise le projet     | `--provider`, `--model`, `--interactive` |
| `watch [PATH]`        | Surveille les fichiers   | `--interactive`, `--auto-run`            |
| `generate FILE`       | Génère un test           | `--context`, `--interactive`, `--output` |
| `test [FILES]`        | Exécute les tests        | `--coverage`, `--watch`                  |
| `report [TYPE]`       | Génère un rapport        | `--output`, `--days`                     |
| `improve TEST SOURCE` | Améliore un test         | `--notes`                                |
| `config`              | Affiche la configuration | -                                        |
| `interactive`         | Mode interactif          | -                                        |
| `version`             | Affiche la version       | -                                        |

## 📊 Exemples d'utilisation

### Exemple 1 : Modèle Rails

**Fichier** : `app/models/user.rb`
```ruby
class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  has_many :posts, dependent: :destroy
  
  def full_name
    "#{first_name} #{last_name}".strip
  end
end
```

**Test généré** : `spec/models/user_spec.rb`
```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
  end

  describe 'associations' do
    it { should have_many(:posts).dependent(:destroy) }
  end

  describe '#full_name' do
    let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

    it 'returns the full name' do
      expect(user.full_name).to eq('John Doe')
    end

    context 'when first_name is blank' do
      let(:user) { build(:user, first_name: '', last_name: 'Doe') }

      it 'returns only last_name' do
        expect(user.full_name).to eq('Doe')
      end
    end
  end
end
```

### Exemple 2 : Contrôleur API

**Fichier** : `app/controllers/api/v1/users_controller.rb`

**Test généré automatiquement** avec :
- Tests CRUD complets
- Gestion des erreurs
- Formats JSON
- Authentification
- Paramètres autorisés

### Exemple 3 : Service métier

**Fichier** : `app/services/payment_processor.rb`

**Test généré** avec :
- Tests des méthodes publiques
- Mocking des APIs externes
- Gestion d'erreurs métier
- Cas limites de paiement

## 🏗️ Architecture technique

### Structure modulaire

```
lib/autotest/ia/
├── configuration.rb     # Configuration globale
├── file_watcher.rb     # Surveillance des fichiers
├── ai_generator.rb     # Génération IA avec langchain.rb
├── test_runner.rb      # Exécution des tests
├── reporter.rb         # Rapports et analyses
└── cli.rb             # Interface ligne de commande
```

### Intégrations

- **Langchain.rb** : Interface unifiée pour les LLMs
- **Listen** : Surveillance efficace des fichiers
- **Thor** : CLI moderne et extensible
- **TTY::Prompt** : Interface interactive intuitive
- **SimpleCov** : Analyse de couverture de code

### Providers IA supportés

- **OpenAI** : GPT-3.5, GPT-4 (recommandé pour la qualité)
- **Ollama** : Models locaux (Code Llama, etc.)
- **Extensible** : Architecture prête pour d'autres providers

## 🎯 Bonnes pratiques

### Configuration optimale

1. **Utilisez GPT-4** pour la meilleure qualité de tests
2. **Activez le mode interactif** pour un contexte métier riche
3. **Configurez un seuil de couverture** approprié (80%+)
4. **Personnalisez les chemins** selon votre architecture

### Workflow recommandé

1. **Initialisation** : `autotest-ia init`
2. **Configuration** : Personnalisez `.autotest_ia.yml`
3. **Surveillance** : `autotest-ia watch` en arrière-plan
4. **Développement** : Codez normalement, les tests se génèrent automatiquement
5. **Validation** : Révisez et ajustez les tests générés
6. **Rapports** : Analysez régulièrement avec `autotest-ia report`

### Optimisation des prompts

Enrichissez le contexte métier pour des tests plus pertinents :

```bash
# Exemple avec contexte riche
autotest-ia generate app/models/order.rb --context "
Modèle de commande e-commerce avec :
- Statuts : pending, confirmed, shipped, delivered, cancelled
- Calcul automatique des taxes selon la localisation
- Intégration Stripe pour les paiements
- Notifications email automatiques
- Gestion des stocks en temps réel
"
```

## 🔍 Dépannage

### Problèmes courants

**Erreur de clé API manquante**
```bash
export OPENAI_API_KEY="sk-..."
autotest-ia config  # Vérifiez la configuration
```

**Tests non générés**
```bash
# Vérifiez les chemins surveillés
autotest-ia config

# Mode debug
autotest-ia generate app/models/user.rb --interactive
```

**Couverture insuffisante**
```bash
# Analysez les fichiers non couverts
autotest-ia report coverage

# Générez les tests manquants
autotest-ia generate app/models/uncovered_model.rb
```

### Logs et debugging

Les logs détaillés sont disponibles dans `tmp/autotest_ia.log`

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Fork le projet
2. Créez votre branche de fonctionnalité (`git checkout -b feature/amazing-feature`)
3. Committez vos changements (`git commit -am 'Add amazing feature'`)
4. Poussez vers la branche (`git push origin feature/amazing-feature`)
5. Ouvrez une Pull Request

### Développement local

```bash
git clone https://github.com/username/autotest-ia.git
cd autotest-ia
bundle install
bundle exec rake spec
```

## 📊 Couverture des tests

Ce projet maintient une couverture de tests élevée grâce à SimpleCov. La couverture actuelle est de **91.04%**.

### Consulter le rapport de couverture

Après avoir exécuté les tests, vous pouvez consulter le rapport détaillé :

```bash
# Exécuter les tests avec couverture
bundle exec rspec

# Ouvrir le rapport HTML (macOS)
open coverage/index.html

# Ouvrir le rapport HTML (Linux)
xdg-open coverage/index.html
```

### Configuration de la couverture

La configuration SimpleCov est définie dans `spec/spec_helper.rb` avec :
- Seuil minimum de couverture : **80%**
- Seuil minimum par fichier : **70%**
- Exclusions : répertoires `spec/`, `vendor/`, `bin/`, etc.
- Groupement par modules pour une analyse claire

### Mise à jour automatique du badge

Un script utilitaire permet de mettre à jour automatiquement le badge de couverture dans le README :

```bash
# Après exécution des tests
./bin/update_coverage_badge
```

Ce script :
- Extrait automatiquement le pourcentage de couverture depuis SimpleCov
- Met à jour le badge avec la couleur appropriée (rouge < 50%, orange < 70%, jaune < 80%, vert foncé < 90%, vert >= 90%)
- Met à jour le tableau de couverture avec le nouveau pourcentage

### Maintenance des badges de dépendances

Un autre script utilitaire vérifie les versions des dépendances principales :

```bash
# Vérifier les versions des dépendances
./bin/check_dependencies
```

Ce script :
- Vérifie les dernières versions disponibles sur RubyGems
- Compare avec les versions configurées dans le gemspec
- Suggère les mises à jour nécessaires pour les badges
- Recommande les actions à prendre

> **💡 Note** : Les badges de dépendances sont automatiquement mis à jour pour refléter les dernières versions compatibles disponibles. Exécutez `./bin/check_dependencies` régulièrement pour maintenir vos badges à jour.

### Mise à jour complète (script maître)

Pour une maintenance complète en une seule commande :

```bash
# Mettre à jour tous les badges et vérifier les dépendances
./bin/update_all_badges
```

Ce script maître :
- Exécute la mise à jour du badge de couverture
- Vérifie les versions des dépendances
- Fournit un rapport complet avec les actions recommandées
- Guide pour les prochaines étapes de maintenance

### Objectifs de couverture

| Composant          | Couverture cible | Status       |
| ------------------ | ---------------- | ------------ |
| Modèles principaux | > 95%            | ✅            |
| CLI et interfaces  | > 85%            | ✅            |
| Utilitaires        | > 90%            | ✅            |
| **Global**         | **> 90%**        | **✅ 91.04%** |

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE.txt](LICENSE.txt) pour plus de détails.

## 🙏 Remerciements

- [Langchain.rb](https://github.com/andreibondarev/langchainrb) pour l'interface IA
- [Listen](https://github.com/guard/listen) pour la surveillance des fichiers  
- [Thor](https://github.com/rails/thor) pour la CLI
- [SimpleCov](https://github.com/simplecov-ruby/simplecov) pour la couverture
- La communauté Ruby/Rails pour l'inspiration


---

**Développé avec ❤️ pour automatiser l'écriture de tests et améliorer la qualité du code Ruby/Rails**

Pour plus d'informations, consultez la [documentation complète](https://github.com/username/autotest-ia/wiki) ou [ouvrez une issue](https://github.com/username/autotest-ia/issues).
