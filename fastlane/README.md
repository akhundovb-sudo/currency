# App Store: тексты и скриншоты

`metadata/<locale>/` — тексты для App Store Connect (en-US, ru, tr, fr-FR, es-ES, de-DE, zh-Hans, ar-SA).
`screenshots/<locale>/` — скриншоты; в репозитории не хранятся (в `.gitignore`), лежат локально.

Загрузка (на Mac, под вашим Apple ID):

```sh
brew install fastlane        # один раз; если уже стоит — brew upgrade fastlane
cd <папка проекта>
fastlane deliver
```

Fastlane спросит Apple ID и пароль (или используйте ключ App Store Connect API через `--api_key_path`).
Он загрузит тексты и скриншоты для каждого языка, на проверку ничего не отправляет.

Ссылки поддержки и политики конфиденциальности (`support_url.txt`, `privacy_url.txt`, `marketing_url.txt`)
не заданы — добавьте файлы в `metadata/<locale>/` со своими адресами или впишите в App Store Connect.
