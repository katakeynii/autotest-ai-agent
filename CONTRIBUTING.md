# 🤝 Guide de Contribution - Autotest IA

Merci de votre intérêt pour contribuer à **autotest-ia** ! Ce guide vous aidera à participer efficacement au développement de ce gem révolutionnaire.

## 🇸🇳 Notre Mission

Autotest IA a été développé au Sénégal avec pour mission de démocratiser l'utilisation de l'IA dans le développement logiciel pour la communauté africaine et mondiale. Vos contributions nous aident à réaliser cette vision.

## 📋 Table des Matières

- [Types de Contributions](#types-de-contributions)
- [Configuration de l'Environnement](#configuration-de-lenvironnement)
- [Processus de Contribution](#processus-de-contribution)
- [Standards de Code](#standards-de-code)
- [Tests](#tests)
- [Documentation](#documentation)
- [Code de Conduite](#code-de-conduite)

## 🎯 Types de Contributions

Nous accueillons différents types de contributions :

### 🐛 Rapports de Bugs
- Signalez les bugs via les [GitHub Issues](https://github.com/username/autotest-ia/issues)
- Utilisez le template de bug report
- Incluez des étapes reproductibles
- Mentionnez votre environnement (Ruby, Rails, OS)

### ✨ Nouvelles Fonctionnalités
- Proposez des améliorations via les issues
- Discutez d'abord les grandes fonctionnalités
- Utilisez le template de feature request
- Considérez l'impact sur l'architecture existante

### 📚 Documentation
- Améliorations du README
- Exemples d'utilisation
- Guides tutoriels
- Corrections de typos

### 🔧 Améliorations du Code
- Optimisations de performance
- Refactoring
- Améliorations de l'UX/CLI
- Support de nouveaux providers IA

## ⚙️ Configuration de l'Environnement

### Prérequis

- **Ruby** 3.0+ 
- **Rails** 7.0+ (pour les tests)
- **Git**
- Clé API OpenAI (pour les tests complets)

### Installation

```bash
# 1. Fork et clone le repository
git clone https://github.com/votre-username/autotest-ia.git
cd autotest-ia

# 2. Installer les dépendances
bundle install

# 3. Lancer les tests pour vérifier l'installation
bundle exec rspec

# 4. Configurer les variables d'environnement (optionnel)
export OPENAI_API_KEY="votre-clé-api"
```

### Structure du Projet

```
autotest-ia/
├── lib/autotest/ia/           # Code principal
│   ├── configuration.rb       # Configuration
│   ├── cli.rb                # Interface CLI
│   ├── ai_generator.rb       # Génération IA
│   ├── file_watcher.rb       # Surveillance fichiers
│   ├── test_runner.rb        # Exécution tests
│   └── reporter.rb           # Rapports
├── spec/                     # Tests RSpec
│   ├── dummy/               # App Rails factice
│   └── fixtures/            # Données de test
├── bin/                     # Scripts utilitaires
└── exe/                     # Exécutable principal
```

## 🚀 Processus de Contribution

### 1. Préparation

```bash
# Créer une branche pour votre fonctionnalité
git checkout -b feature/ma-nouvelle-fonctionnalite

# Ou pour un bugfix
git checkout -b fix/correction-bug-important
```

### 2. Développement

- **Suivez les standards de code** (voir section dédiée)
- **Écrivez des tests** pour votre code
- **Documentez** les nouvelles fonctionnalités
- **Testez localement** avant de soumettre

### 3. Tests

```bash
# Lancer tous les tests
bundle exec rspec

# Tests avec couverture
bundle exec rspec
open coverage/index.html

# Vérifier la qualité du code
bundle exec rubocop

# Mettre à jour les badges
./bin/update_all_badges
```

### 4. Soumission

```bash
# Commit avec des messages descriptifs
git add .
git commit -m "feat: ajouter support pour Ollama local

- Configurer l'intégration Ollama
- Ajouter tests pour les modèles locaux
- Mettre à jour la documentation

Closes #42"

# Push et création de la PR
git push origin feature/ma-nouvelle-fonctionnalite
```

## 📝 Standards de Code

### Style Ruby

- **Suivez Rubocop** : `bundle exec rubocop`
- **Conventions Rails** standard
- **Noms explicites** pour classes, méthodes et variables
- **Documentation** des méthodes publiques

### Exemples

```ruby
# ✅ Bon
class AIGenerator
  # Génère un test pour le fichier spécifié
  # @param file_path [String] Chemin vers le fichier source
  # @param context [Hash] Contexte additionnel pour l'IA
  # @return [String, nil] Code du test généré ou nil en cas d'erreur
  def generate_test_for(file_path, context: {})
    # implémentation...
  end
end

# ❌ Éviter
class Gen
  def gen(f, c = {})
    # implémentation...
  end
end
```

### Messages de Commit

Utilisez la convention [Conventional Commits](https://www.conventionalcommits.org/) :

```
feat: ajouter support pour Claude AI
fix: corriger l'erreur de parsing des tests RSpec
docs: mettre à jour les exemples d'utilisation
refactor: simplifier la logique de détection de fichiers
test: ajouter tests pour les controllers Rails
```

## 🧪 Tests

### Structure des Tests

- **Tests unitaires** : `spec/autotest/agent/`
- **Tests d'intégration** : `spec/integration/`
- **Fixtures** : `spec/fixtures/`
- **App factice** : `spec/dummy/`

### Écriture de Tests

```ruby
# spec/autotest/agent/ai_generator_spec.rb
RSpec.describe Autotest::Agent::AIGenerator do
  let(:config) { test_configuration }
  let(:generator) { described_class.new(config) }

  describe '#generate_test_for' do
    context 'avec un modèle Rails valide' do
      it 'génère un test RSpec complet' do
        # Test implementation
      end
    end

    context 'avec un fichier invalide' do
      it 'lève une erreur explicite' do
        # Test implementation
      end
    end
  end
end
```

### Couverture de Tests

- **Objectif** : > 90% de couverture globale
- **Minimum** : 70% par fichier
- **Vérification** : `./bin/update_coverage_badge`

## 📖 Documentation

### Code

- **Commentaires YARD** pour les méthodes publiques
- **Exemples d'usage** dans les docstrings
- **Types de paramètres** spécifiés

### README

- **Exemples pratiques** pour chaque fonctionnalité
- **Screenshots** ou captures d'écran si pertinent
- **Troubleshooting** pour les problèmes courants

### CHANGELOG

Mettez à jour `CHANGELOG.md` pour chaque changement :

```markdown
## [1.2.0] - 2024-01-15

### Ajouté
- Support pour Ollama et modèles locaux
- Nouvelle commande `autotest-ia doctor` pour diagnostics

### Corrigé
- Erreur de parsing des fichiers contenant des caractères spéciaux

### Modifié
- Amélioration des performances de surveillance de fichiers
```

## 🤖 Intégration avec l'IA

### Tests des Providers IA

```bash
# Tests avec OpenAI (nécessite OPENAI_API_KEY)
PROVIDER=openai bundle exec rspec spec/integration/

# Tests avec mocks (pas de clé API requise)
bundle exec rspec spec/autotest/agent/ai_generator_spec.rb
```

### Nouveaux Providers

Pour ajouter un nouveau provider IA :

1. Créer le module dans `AIGenerator`
2. Ajouter les tests correspondants
3. Mettre à jour la documentation
4. Ajouter l'exemple d'usage

## 🌍 Internationalisation

- **Français** : Langue principale (Sénégal)
- **Anglais** : Langue secondaire (international)
- Messages d'erreur en français avec traductions anglaises si pertinent

## 🚨 Code de Conduite

Ce projet suit le [Code de Conduite Contributor Covenant](CODE_OF_CONDUCT.md). En participant, vous vous engagez à respecter ce code.

### Nos Engagements

- **Respect** et bienveillance envers tous les contributeurs
- **Inclusion** de la diversité des expériences et points de vue
- **Constructivité** dans les critiques et discussions
- **Focus** sur ce qui est meilleur pour la communauté

## 🎉 Reconnaissance

### Hall of Fame

Les contributeurs remarquables seront mentionnés dans :
- Le README principal
- Les notes de release
- Les remerciements spéciaux

### Première Contribution

- Label `good first issue` pour les débutants
- Mentorat disponible via issues ou discussions
- Documentation dédiée pour démarrer

## 📞 Besoin d'Aide ?

- **Issues GitHub** : Pour questions techniques
- **Discussions** : Pour brainstorming et idées
- **Email** : mohamed-camara.gueye@free-partenaires.sn

## 🇸🇳 Fierté Sénégalaise

Ce projet représente l'excellence technologique sénégalaise. Chaque contribution aide à :
- Renforcer l'écosystème tech africain
- Inspirer la prochaine génération de développeurs
- Démontrer l'innovation "Made in Senegal"

---

**Merci de contribuer à autotest-ia ! Ensemble, révolutionnons l'écriture de tests avec l'IA.** 🚀

**Développé avec ❤️ au Sénégal 🇸🇳** 