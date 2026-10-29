# App Store: тексты

`metadata/<locale>/` — тексты для App Store Connect: en-US, ru, tr, fr-FR, es-ES, de-DE, zh-Hans, ar-SA
(name, subtitle, promotional_text, description, keywords, support_url). Тексты — из файла Cento_App_Store_All_Texts.txt.

Загрузка на Mac, под вашим Apple ID:

```sh
brew install fastlane   # один раз
cd <папка проекта>
fastlane deliver
```

Fastlane спросит Apple ID и пароль и заполнит тексты для каждого языка. Скриншоты, сборку и отправку на проверку не трогает:
после загрузки откройте App Store Connect, проверьте и нажмите «Add for Review».

Ссылка поддержки: https://akhundovb.com/. Политика конфиденциальности не задана: добавьте `privacy_url.txt`
в `metadata/<locale>/` или впишите ссылку в App Store Connect. Испанский текст лежит в `es-ES`; для Мексики скопируйте папку в `es-MX`.
«What's New» для версии 1.0 не нужен, поэтому `release_notes.txt` нет.
