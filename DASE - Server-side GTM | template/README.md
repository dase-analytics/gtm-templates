# DASE – Server-Side GTM | Template

[![Download JSON](https://img.shields.io/badge/Download-Container-blue)](dase_sgtm_template.json)
[![GA4 Compatible](https://img.shields.io/badge/GA4-Compatible-brightgreen)](https://developers.google.com/tag-platform/tag-manager/server-side/overview)
[![Version](https://img.shields.io/badge/Version-1.0.0-orange)]()


## Obsah
- [Prehľad](#prehľad)
- [Import do Google Tag Managera](#import-do-google-tag-managera)
- [Nastavenie a použitie](#nastavenie-a-použitie)
- [Changelog](#changelog)
- [Kontakt a odkazy](#kontakt-a-odkazy)


## Prehľad  
Táto šablóna slúži na základné nastavenie **serverového GTM kontajnera**.  
Predpokladá:  
- správne nastavené merania v klientskom kontajneri  
- mapovanie servera na vlastnú (sub)doménu  

Obsahuje:  
- **GA4 klient** – spracováva Google Analytics requesty  
- **GTM web container klient** – umožňuje načítanie Google skriptov (napr. `gtm.js`, `gtag.js`) zo serveru  
- **GTM custom loader klient** – umožňuje nastaviť vlastnú cestu na načítanie GTM knižnice  
- **GA4 tag**  

<br>
<img src="images/sgtm_clients.png" alt="Server-side GTM clients" width="60%">
<br>


## Import do Google Tag Managera  
1. V kontajneri prejdite do sekcie **Správca**.  
2. Kliknite na **Importovať kontajner**.  
3. Vyberte súbor stiahnutý z GitHub repozitára.  
4. Odporúčame vytvoriť si nový pracovný priestor:  
   - kliknite na **Vybrať pracovný priestor**  
   - vpravo hore kliknite na **+**  
5. V sekcii **Vyberte možnosť importu** zvoľte požadovanú voľbu.  
   - ak chcete prepísať existujúci obsah, vyberte **Prepísať**  


## Nastavenie a použitie  
0. V konfiguračnom tagu v **klientskom kontajneri** vložte parameter `server_container_url` s hodnotou adresy vášho GTM servera.  

<br>
<img src="images/sgtm_url_config.png" alt="Server-side GTM server_container_url" width="60%">
<br>

1. V premennej **`GA4 - Measurement ID`** nahraďte hodnotu `G-XXXXXXXX` vašim Measurement ID.  
2. V premennej **`GTM - web container id`** nahraďte hodnotu `GTM-XXXXXX` ID vášho klientského kontajnera.  
3. *(Voliteľné)* – ak chcete nastaviť vlastnú cestu ku GTM knižnici, v premennej **`GTM - request path`** nahraďte hodnotu `/<custom-path>.js`.  
4. V sekcii **Správca → Nastavenia kontajnera** pridajte URL serverového kontajnera.  

<br>
<img src="images/sgtm_preview_url.png" alt="Server-side GTM Preview URL" width="60%">
<br>


## Changelog  
- **1.0.0** – Prvé vydanie šablóny


## Kontakt a odkazy  
Máte nejaké otázky alebo nejasnosti? Napíšte nám na **cibula@dase.sk**  

👉 [Dase Blog](https://www.dase-analytics.com/blog/sk/)  
👉 [Dase Instagram](https://www.instagram.com/daseanalytics/)
