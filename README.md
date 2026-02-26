# Minecraft 1.21 Android: Industrial Mobile (Bedrock Addon)

Это репозиторий с **базой мода/аддона для телефона (Android)** под Minecraft Bedrock 1.21 в стиле industrial.

## Важный момент про IndustrialCraft

IndustrialCraft из Java-версии Minecraft нельзя «просто перенести» на Android Bedrock 1:1:
- другой движок (Java Edition vs Bedrock Edition),
- другой API и формат моддинга,
- прямое копирование чужого кода/ассетов может нарушать лицензию.

Поэтому здесь сделан **чистый стартовый аналог по идее**, а не копия исходников IndustrialCraft.

## Что есть в репозитории

См. `industrial-mobile-addon/README.md`:
- behavior pack + resource pack,
- базовые индустриальные предметы,
- блок электропечи,
- стартовый рецепт переплавки.

## Что добавить, чтобы приблизиться к IC-стилю

- Энергосеть (кабель + генератор + хранение EU-аналога).
- Машины: macerator, extractor, compressor.
- Руды/пыль/слитки и технологические цепочки.
- Продвинутые инструменты/броня.
- Script API-логику прогресса машин и передачи энергии.

