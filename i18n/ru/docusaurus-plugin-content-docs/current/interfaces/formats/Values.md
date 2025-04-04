---
title: Values
slug: /interfaces/formats/Values
keywords: ['Values']
input_format: true
output_format: true
alias: []
---

| Вход | Выход | Псевдоним |
|------|-------|-----------|
| ✔    | ✔     |           |

## Описание {#description}

Формат `Values` выводит каждую строку в скобках.

- Строки разделяются запятыми, без запятой после последней строки.
- Значения внутри скобок также разделяются запятыми.
- Числа выводятся в десятичном формате без кавычек.
- Массивы выводятся в квадратных скобках.
- Строки, даты и даты с временем выводятся в кавычках.
- Правила экранирования и парсинга аналогичны формату [TabSeparated](TabSeparated/TabSeparated.md).

При форматировании дополнительные пробелы не вставляются, но при парсинге они разрешены и игнорируются (за исключением пробелов внутри значений массива, которые не допускаются).
[`NULL`](/sql-reference/syntax.md) представляется как `NULL`.

Минимальный набор символов, которые необходимо экранировать при передаче данных в формате `Values`:
- одинарные кавычки
- обратные слэши

Это формат, который используется в `INSERT INTO t VALUES ...`, но вы также можете использовать его для форматирования результатов запросов.

## Пример использования {#example-usage}

## Настройки формата {#format-settings}

| Настройка                                                                                                                                                      | Описание                                                                                                                                                                                    | По умолчанию |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------|
| [`input_format_values_interpret_expressions`](../../operations/settings/settings-formats.md/#input_format_values_interpret_expressions)                     | если поле не может быть разобрано потоковым парсером, запустить SQL парсер и попытаться интерпретировать его как SQL выражение.                                                           | `true`       |
| [`input_format_values_deduce_templates_of_expressions`](../../operations/settings/settings-formats.md/#input_format_values_deduce_templates_of_expressions) | если поле не может быть разобрано потоковым парсером, запустить SQL парсер, вывести шаблон SQL выражения, попытаться разобрать все строки, используя шаблон, а затем интерпретировать выражение для всех строк. | `true`       |
| [`input_format_values_accurate_types_of_literals`](../../operations/settings/settings-formats.md/#input_format_values_accurate_types_of_literals)           | при парсинге и интерпретации выражений с использованием шаблона, проверять фактический тип литерала, чтобы избежать возможного переполнения и проблем с точностью.                        | `true`       |
