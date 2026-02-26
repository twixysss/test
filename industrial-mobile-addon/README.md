# Industrial Mobile Addon (Minecraft Bedrock 1.21, Android)

Этот проект — **стартовый аддон для Minecraft Bedrock 1.21 на Android** в стиле техно/индастриал.

> Важно: это не копия IndustrialCraft и не перенос чужого кода. Вместо этого — легальная база с похожим направлением (машины, переработка ресурсов, генерация энергии как концепт).

## Что реализовано

- Блок `industrial:electric_furnace` (электропечь, базовая машина).
- Предмет `industrial:raw_tin` (сырой оловянный ресурс).
- Предмет `industrial:tin_ingot` (оловянный слиток).
- Рецепт переплавки сырого олова в слиток через электропечь.
- Готовая структура BP/RP для установки на телефон.

## Структура

```
industrial-mobile-addon/
├── behavior_pack/
│   ├── manifest.json
│   ├── blocks/electric_furnace.json
│   ├── items/raw_tin.json
│   ├── items/tin_ingot.json
│   └── recipes/tin_ingot_from_raw_tin.json
└── resource_pack/
    ├── manifest.json
    ├── blocks.json
    └── texts/en_US.lang
```

## Установка на Android

1. Скопируй папки `behavior_pack` и `resource_pack` в:
   - `games/com.mojang/behavior_packs/`
   - `games/com.mojang/resource_packs/`
2. Открой мир → **Настройки** → **Наборы ресурсов** и **Наборы параметров**.
3. Активируй оба набора (`Industrial Mobile RP`, `Industrial Mobile BP`).
4. Включи эксперименты, если мир требует (зависит от версии клиента).

## Дальше можно добавить

- Генератор энергии + аккумулятор.
- Дробитель руды (macerator) с выходом пыли.
- Провода и простую энергосеть на Script API.
- Автокрафт и мультиблочные механизмы.

