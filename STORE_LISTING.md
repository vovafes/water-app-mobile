# Store listing copy

Everything the two consoles ask you to type, written once, in all four
languages the app ships. Paste from here rather than improvising in the
console — the fields have hard character limits, the console truncates
silently in some of them, and a listing edit after publishing goes through
review again.

**The product name is still undecided.** `README.md` says "HydroTrack",
`strings.xml` and `Info.plist` say "Water App". Everything below uses
**Water App**, which is what a user actually sees on their home screen. If
you settle on the other one, it changes here, in both platform manifests,
and in the listing — and after first publish the store name is editable but
the `applicationId` is not. Settle it first.

Nothing here promises a feature that does not exist. Health sync, widgets
and watch apps are real plans (MONETIZATION.md §3) and must stay out of the
listing until they ship: both review teams strike "coming soon" from store
copy, and Apple rejects for it.

## Limits, and where each field goes

| Field | Limit | Google Play | App Store |
|---|---|---|---|
| App name | 30 | ✅ | ✅ |
| Subtitle | 30 | — | ✅ |
| Short description | 80 | ✅ | — |
| Promotional text | 170 | — | ✅ (editable without review) |
| Full description | 4000 | ✅ | ✅ |
| Keywords | 100 | — | ✅ (comma-separated, no spaces) |

Play has no keyword field — it indexes the descriptions, which is why the
long copy below repeats "water", "hydration" and "reminder" in natural
sentences rather than in a list.

Apple's **promotional text** is the one field you can change any day without
a review. Use it for seasonal pushes; leave the description alone.

---

## English

**App name**
```
Water App: Hydration Tracker
```

**Subtitle** (App Store)
```
Hydration that counts right
```

**Short description** (Play)
```
Your real water target — and every drink counted at what it's actually worth
```

**Promotional text** (App Store)
```
Coffee counts. Tea counts. Water App works out what each drink is really worth to your body, and what your own target should be.
```

**Keywords** (App Store)
```
water,hydration,drink,tracker,reminder,intake,health,habit,streak,coffee,tea,goal
```

**Full description**
```
Most water trackers give everyone the same number and treat every drink the same. Water App does neither.

YOUR NUMBER, NOT A ROUND ONE
Eight questions — sex, age, weight, height, how much you move, the climate you live in, how you sleep — and you get a daily target calculated for you. Not 2 litres because 2 litres sounds tidy.

EVERY DRINK AT ITS REAL VALUE
Coffee does not dehydrate you, and pretending otherwise is why so many trackers feel wrong. Water App counts each drink at its actual hydration coefficient, so a cup of tea contributes what a cup of tea contributes. Log it in two taps from the drink grid.

REMINDERS THAT KNOW WHEN TO SHUT UP
Set an interval or fixed times, choose which days, and set quiet hours that are actually quiet. No buzzing at 3am because you forgot to close the app.

SEE THE HABIT FORM
Every day is kept and grouped, with a calendar view and streaks. Achievements mark the milestones that are worth marking. Hydration tips, written for the language you read in.

YOURS TO CONTROL
Light, dark or system theme. Four languages: English, German, Russian, Ukrainian. Delete your account and everything in it from inside the app, in two taps, no email required.

PREMIUM
The free plan keeps a week of history, one reminder schedule, and water, tea and coffee. Premium adds a target that recalculates for the weather and your day, the full drink library plus your own custom drinks, unlimited reminder schedules, complete history with trends, every achievement, the whole tips library, and CSV export of everything you have ever logged.

Available as a monthly or yearly subscription, or a single lifetime purchase. Subscriptions renew automatically unless cancelled at least 24 hours before the period ends, and are managed in your store account.

Terms: {SITE}/terms
Privacy: {SITE}/privacy

Water App is a wellness tool, not a medical device. The targets it shows are general estimates from the details you enter. If a health condition affects how much you should drink, talk to your doctor.
```

---

## Deutsch

**App name**
```
Water App: Trink-Tracker
```

**Subtitle**
```
Trinken, richtig gezählt
```

**Short description**
```
Dein echter Wasserbedarf – jedes Getränk zählt so viel, wie es wirklich zählt
```

**Promotional text**
```
Kaffee zählt. Tee zählt. Water App berechnet, was jedes Getränk deinem Körper wirklich bringt – und wie hoch dein eigener Bedarf ist.
```

**Keywords**
```
wasser,trinken,tracker,erinnerung,hydration,gesundheit,gewohnheit,kaffee,tee,ziel
```

**Full description**
```
Die meisten Trink-Tracker geben allen dieselbe Zahl und behandeln jedes Getränk gleich. Water App macht weder das eine noch das andere.

DEINE ZAHL, KEINE RUNDE
Acht Fragen – Geschlecht, Alter, Gewicht, Größe, wie viel du dich bewegst, in welchem Klima du lebst, wie du schläfst – und du bekommst ein Tagesziel, das für dich berechnet ist. Nicht 2 Liter, weil 2 Liter ordentlich klingt.

JEDES GETRÄNK MIT SEINEM ECHTEN WERT
Kaffee entwässert dich nicht, und das Gegenteil zu behaupten ist der Grund, warum sich so viele Tracker falsch anfühlen. Water App rechnet jedes Getränk mit seinem tatsächlichen Hydrationskoeffizienten. Eine Tasse Tee trägt genau das bei, was eine Tasse Tee beiträgt. Zwei Tipps im Getränkeraster, fertig.

ERINNERUNGEN, DIE AUCH MAL STILL SIND
Intervall oder feste Zeiten, Wochentage deiner Wahl, und Ruhezeiten, die wirklich ruhig bleiben. Kein Summen um drei Uhr nachts.

SIEH DIE GEWOHNHEIT ENTSTEHEN
Jeder Tag wird gespeichert und gruppiert, mit Kalenderansicht und Serien. Erfolge markieren die Meilensteine, die es wert sind. Dazu Trink-Tipps in deiner Sprache.

DU BEHÄLTST DIE KONTROLLE
Helles, dunkles oder System-Design. Vier Sprachen: Deutsch, Englisch, Russisch, Ukrainisch. Konto und alle Daten direkt in der App löschen – zwei Tipps, keine E-Mail nötig.

PREMIUM
Der kostenlose Plan behält eine Woche Verlauf, einen Erinnerungsplan sowie Wasser, Tee und Kaffee. Premium ergänzt ein Ziel, das sich täglich an Wetter und Tagesablauf anpasst, die vollständige Getränkebibliothek samt eigener Getränke, unbegrenzte Erinnerungspläne, den kompletten Verlauf mit Trends, alle Erfolge, die gesamte Tipp-Bibliothek und CSV-Export aller Einträge.

Erhältlich als Monats- oder Jahresabo oder als einmaliger Lifetime-Kauf. Abos verlängern sich automatisch, sofern sie nicht mindestens 24 Stunden vor Ende des Zeitraums gekündigt werden; die Verwaltung erfolgt im Konto deines Stores.

Nutzungsbedingungen: {SITE}/terms
Datenschutz: {SITE}/privacy

Water App ist ein Wellness-Werkzeug, kein Medizinprodukt. Die angezeigten Ziele sind allgemeine Schätzungen auf Basis deiner Angaben. Wenn eine Erkrankung deine Trinkmenge beeinflusst, sprich mit deiner Ärztin oder deinem Arzt.
```

---

## Русский

**App name**
```
Water App: трекер воды
```

**Subtitle**
```
Норма воды по-настоящему
```

**Short description**
```
Ваша настоящая норма воды — и каждый напиток по реальному вкладу
```

**Promotional text**
```
Кофе считается. Чай считается. Water App считает, что каждый напиток реально даёт организму, и какая норма именно ваша.
```

**Keywords**
```
вода,трекер,напоминание,гидратация,норма,здоровье,привычка,кофе,чай,цель
```

**Full description**
```
Большинство трекеров воды выдают всем одну и ту же цифру и считают все напитки одинаковыми. Water App не делает ни того, ни другого.

ВАША ЦИФРА, А НЕ КРУГЛАЯ
Восемь вопросов — пол, возраст, вес, рост, сколько двигаетесь, в каком климате живёте, как спите — и вы получаете дневную норму, посчитанную под вас. Не 2 литра, потому что 2 литра звучит аккуратно.

КАЖДЫЙ НАПИТОК ПО РЕАЛЬНОМУ ВКЛАДУ
Кофе вас не обезвоживает, и вера в обратное — причина, по которой многие трекеры ощущаются неправильными. Water App считает каждый напиток по его настоящему коэффициенту гидратации: чашка чая даёт ровно то, что даёт чашка чая. Запись — два касания в сетке напитков.

НАПОМИНАНИЯ, КОТОРЫЕ УМЕЮТ МОЛЧАТЬ
Интервал или фиксированное время, выбранные дни недели и тихие часы, которые действительно тихие. Никакой вибрации в три ночи.

КАК ФОРМИРУЕТСЯ ПРИВЫЧКА
Каждый день сохраняется и группируется, есть календарь и серии дней. Достижения отмечают то, что стоит отметить. Плюс советы о питьевом режиме на вашем языке.

ВСЁ ПОД ВАШИМ КОНТРОЛЕМ
Светлая, тёмная или системная тема. Четыре языка: русский, украинский, английский, немецкий. Удалить аккаунт и все данные можно прямо в приложении — два касания, без писем в поддержку.

PREMIUM
Бесплатный план хранит неделю истории, одно расписание напоминаний и воду, чай и кофе. Premium добавляет норму, которая пересчитывается под погоду и ваш день, полную библиотеку напитков и свои собственные, неограниченные расписания напоминаний, всю историю с трендами, все достижения, полную ленту советов и экспорт всех записей в CSV.

Доступно как месячная или годовая подписка либо как разовая покупка навсегда. Подписка продлевается автоматически, если не отменить её не позднее чем за 24 часа до конца периода; управление — в аккаунте магазина.

Условия использования: {SITE}/terms
Конфиденциальность: {SITE}/privacy

Water App — инструмент для здорового образа жизни, а не медицинское изделие. Показанные нормы — общие оценки по введённым вами данным. Если на объём питья влияет заболевание, обсудите его с врачом.
```

---

## Українська

**App name**
```
Water App: трекер води
```

**Subtitle**
```
Норма води по-справжньому
```

**Short description**
```
Ваша справжня норма води — і кожен напій за реальним внеском
```

**Promotional text**
```
Кава рахується. Чай рахується. Water App рахує, що кожен напій справді дає організму, і якою є саме ваша норма.
```

**Keywords**
```
вода,трекер,нагадування,гідратація,норма,здоров'я,звичка,кава,чай,ціль
```

**Full description**
```
Більшість трекерів води видають усім однакову цифру й рахують усі напої однаково. Water App не робить ні того, ні іншого.

ВАША ЦИФРА, А НЕ КРУГЛА
Вісім запитань — стать, вік, вага, зріст, скільки рухаєтесь, у якому кліматі живете, як спите — і ви отримуєте денну норму, пораховану саме для вас. Не 2 літри, бо 2 літри звучить охайно.

КОЖЕН НАПІЙ ЗА РЕАЛЬНИМ ВНЕСКОМ
Кава вас не зневоднює, і віра в протилежне — причина, чому багато трекерів відчуваються неправильними. Water App рахує кожен напій за його справжнім коефіцієнтом гідратації: горнятко чаю дає рівно те, що дає горнятко чаю. Запис — два дотики в сітці напоїв.

ЯК ФОРМУЄТЬСЯ ЗВИЧКА
Кожен день зберігається та групується, є календар і серії днів. Досягнення відзначають те, що варто відзначити. А ще поради про питний режим вашою мовою.

НАГАДУВАННЯ, ЯКІ ВМІЮТЬ МОВЧАТИ
Інтервал або фіксований час, обрані дні тижня та тихі години, які справді тихі. Жодної вібрації о третій ночі.

УСЕ ПІД ВАШИМ КОНТРОЛЕМ
Світла, темна або системна тема. Чотири мови: українська, англійська, німецька, російська. Видалити акаунт і всі дані можна просто в застосунку — два дотики, без листів у підтримку.

PREMIUM
Безкоштовний план зберігає тиждень історії, одне розклад нагадувань і воду, чай та каву. Premium додає норму, що перераховується під погоду і ваш день, повну бібліотеку напоїв і власні напої, необмежені розклади нагадувань, усю історію з трендами, усі досягнення, повну стрічку порад та експорт усіх записів у CSV.

Доступно як місячна чи річна підписка або як разова купівля назавжди. Підписка поновлюється автоматично, якщо не скасувати її щонайменше за 24 години до кінця періоду; керування — в акаунті магазину.

Умови використання: {SITE}/terms
Конфіденційність: {SITE}/privacy

Water App — інструмент для здорового способу життя, а не медичний виріб. Показані норми — загальні оцінки за введеними вами даними. Якщо на обсяг питва впливає захворювання, обговоріть його з лікарем.
```

---

## Before pasting

Replace `{SITE}` with the real domain. Until the HTTPS host exists there is
nothing to point at, and a listing with a dead Terms link is worse than one
without it.

**Screenshots are still missing entirely** and cannot be taken from copy.
What each console wants:

- **Play** — phone screenshots (2–8, min 320px on the short side) and a
  feature graphic at exactly 1024×500. The feature graphic has no text
  requirement but is shown above the listing, so it carries the brand.
  Tablet screenshots are optional but their absence downranks the listing on
  tablets.
- **App Store** — 6.9" is mandatory; other sizes are derived from it. If
  iPad is left in the supported devices list, iPad screenshots become
  mandatory too, so decide whether iPad is supported before you shoot.

Take them on the same account with the same data in all four languages, so
the numbers on screen match the language of the text beside them. Screenshots
in English on a Russian listing are legal but read as machine translation.
