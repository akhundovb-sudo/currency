# App Store: тексты

`metadata/<locale>/` — тексты для App Store Connect: en-US, ru, tr, fr-FR, es-ES, de-DE, zh-Hans, ar-SA
(name, subtitle, promotional_text, description, keywords, release_notes).

Загрузка на Mac, под вашим Apple ID:

```sh
brew install fastlane   # один раз
cd <папка проекта>
fastlane deliver
```

Fastlane спросит Apple ID и пароль и заполнит тексты для каждого языка. Скриншоты, сборку и отправку на проверку не трогает:
после загрузки откройте App Store Connect, проверьте и нажмите «Add for Review».

Ссылки поддержки и политики конфиденциальности не заданы: добавьте `support_url.txt`, `privacy_url.txt` (и при желании `marketing_url.txt`)
в `metadata/<locale>/` или впишите их в App Store Connect.
