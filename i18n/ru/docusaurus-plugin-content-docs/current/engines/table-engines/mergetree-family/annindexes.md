---
slug: /engines/table-engines/mergetree-family/annindexes
sidebar_label: Индексы векторного сходства
description: Приближенный поиск ближайших соседей с использованием индексов векторного сходства
keywords: [векторное сходство, текстовый поиск, анн, индексы, индекс, ближайший сосед]
title: "Приближенный поиск ближайших соседей с использованием индексов векторного сходства"
---

import ExperimentalBadge from '@theme/badges/ExperimentalBadge';
import PrivatePreviewBadge from '@theme/badges/PrivatePreviewBadge';


# Приближенный поиск ближайших соседей с использованием индексов векторного сходства

<ExperimentalBadge/>
<PrivatePreviewBadge/>

Поиск ближайших соседей — это задача поиска M ближайших векторов к заданному вектору в N-мерном векторном пространстве. Наиболее простой подход для решения этой задачи — это исчерпывающий (грубый) поиск, который вычисляет расстояние между опорным вектором и всеми остальными точками в векторном пространстве. Хотя этот метод гарантирует абсолютно точный результат, он обычно слишком медленный для практических приложений. В качестве альтернативы, [приближенные алгоритмы](https://github.com/erikbern/ann-benchmarks) используют жадные эвристики для более быстрого нахождения M ближайших векторов. Это позволяет выполнять семантический поиск изображений, песен, текста
[встраиваний](https://cloud.google.com/architecture/overview-extracting-and-serving-feature-embeddings-for-machine-learning) за миллисекунды.

Блоги:
- [Поиск векторов с ClickHouse - Часть 1](https://clickhouse.com/blog/vector-search-clickhouse-p1)
- [Поиск векторов с ClickHouse - Часть 2](https://clickhouse.com/blog/vector-search-clickhouse-p2)

С точки зрения SQL, поиск ближайших соседей может быть выражен следующим образом:

``` sql
SELECT [...]
FROM table, [...]
ORDER BY DistanceFunction(vectors, reference_vector)
LIMIT N
```

где
- `DistanceFunction` вычисляет расстояние между двумя векторами (например, [L2Distance](/sql-reference/functions/distance-functions#l2distance) или
  [cosineDistance](/sql-reference/functions/distance-functions#cosinedistance),
- `vectors` — это колонка типа [Array(Float64)](../../../sql-reference/data-types/array.md) или
  [Array(Float32)](../../../sql-reference/data-types/array.md), или [Array(BFloat16)](../../../sql-reference/data-types/array.md), обычно
  хранящая встраивания,
- `reference_vector` — это литерал типа [Array(Float64)](../../../sql-reference/data-types/array.md) или
  [Array(Float32)](../../../sql-reference/data-types/array.md), или [Array(BFloat16)](../../../sql-reference/data-types/array.md), и
- `N` — это константное целое число, ограничивающее количество возвращаемых результатов.

Запрос возвращает `N` ближайших точек в `vectors` к `reference_vector`.

Исчерпывающий поиск вычисляет расстояние между `reference_vector` и всеми векторами в `vectors`. Таким образом, его время выполнения линейно зависит от
количества хранимых векторов. Приблизительный поиск полагается на специальные структуры данных (например, графы, случайные леса и т.д.), которые позволяют быстро находить
ближайшие векторы к заданному опорному вектору (т.е. за подполевое время). ClickHouse предоставляет такую структуру данных в форме
"индексов векторного сходства", типа [индекса пропуска](mergetree.md#table_engine-mergetree-data_skipping-indexes).


# Создание и использование индексов векторного сходства

Синтаксис для создания индекса векторного сходства

```sql
CREATE TABLE table
(
  id Int64,
  vectors Array(Float32),
  INDEX index_name vectors TYPE vector_similarity(method, distance_function[, quantization, hnsw_max_connections_per_layer, hnsw_candidate_list_size_for_construction]) [GRANULARITY N]
)
ENGINE = MergeTree
ORDER BY id;
```

:::note
Индексы USearch в настоящее время являются экспериментальными, для их использования вам сначала нужно установить `SET allow_experimental_vector_similarity_index = 1`.
:::

Индекс может быть создан на колонках типа [Array(Float64)](../../../sql-reference/data-types/array.md) или
[Array(Float32)](../../../sql-reference/data-types/array.md).

Параметры индекса:
- `method`: В настоящее время поддерживается только `hnsw`.
- `distance_function`: либо `L2Distance` ( [Евклидово расстояние](https://en.wikipedia.org/wiki/Euclidean_distance): длина линии
  между двумя точками в евклидова пространстве), либо `cosineDistance` ( [косинусное
  расстояние](https://en.wikipedia.org/wiki/Cosine_similarity#Cosine_distance): угол между двумя ненулевыми векторами).
- `quantization`: либо `f64`, `f32`, `f16`, `bf16`, или `i8` для хранения векторов с уменьшенной точностью (необязательно, по умолчанию: `bf16`)
- `hnsw_max_connections_per_layer`: количество соседей на узел графа HNSW, также известное как `M` в [документе HNSW](https://doi.org/10.1109/TPAMI.2018.2889473). Необязательно, по умолчанию: `32`. Значение `0` означает использование значения по умолчанию.
- `hnsw_candidate_list_size_for_construction`: размер динамического списка кандидатов при построении графа HNSW, также известный как `ef_construction` в оригинальном [документе HNSW](https://doi.org/10.1109/TPAMI.2018.2889473). Необязательно, по умолчанию: `128`. Значение `0` означает использование значения по умолчанию.

Для нормализованных данных `L2Distance` обычно является наилучшим выбором, в противном случае рекомендуется `cosineDistance`, чтобы компенсировать масштаб.

Пример:

```sql
CREATE TABLE table
(
  id Int64,
  vectors Array(Float32),
  INDEX idx vectors TYPE vector_similarity('hnsw', 'L2Distance') -- Альтернативный синтаксис: TYPE vector_similarity(hnsw, L2Distance)
)
ENGINE = MergeTree
ORDER BY id;
```

Все массивы должны иметь одинаковую длину. Чтобы избежать ошибок, вы можете использовать
[CONSTRAINT](/sql-reference/statements/create/table.md#constraints), например, `CONSTRAINT constraint_name_1 CHECK
length(vectors) = 256`. Пустые `Arrays` и неопределенные значения `Array` в операциях INSERT (т.е. значения по умолчанию) также не поддерживаются.

Индексы векторного сходства основаны на [библиотеке USearch](https://github.com/unum-cloud/usearch), которая реализует [алгоритм HNSW](https://arxiv.org/abs/1603.09320), т.е. наерархический граф, где каждый узел представляет вектор, а ребра между узлами представляют сходство. Такие иерархические структуры могут быть очень эффективными при работе с большими коллекциями. Они могут извлекать 0.05% или меньше данных из общего набора данных, при этом обеспечивая 99% полноту. Это особенно полезно при работе с высокоразмерными векторами, которые дорого загружать и сравнивать. USearch также использует SIMD для ускорения вычислений расстояний на современных процессорах x86 (AVX2 и AVX-512) и ARM (NEON и SVE).

Индексы векторного сходства строятся во время вставки колонок и слияния. Известно, что алгоритм HNSW обеспечивает медленные вставки. В результате,
операции `INSERT` и `OPTIMIZE` на таблицах с индексом векторного сходства будут медленнее, чем для обычных таблиц. Индексы векторного сходства
предпочтительно использовать только с неизменяемыми или редко изменяемыми данными, когда количество обращений на чтение значительно превышает количество записей. Рекомендуется три дополнительных метода для ускорения создания индекса:
- Создание индекса может быть параллелизовано. Максимальное количество потоков можно настроить с помощью серверной настройки
  [max_build_vector_similarity_index_thread_pool_size](../../../operations/server-configuration-parameters/settings.md#server_configuration_parameters_max_build_vector_similarity_index_thread_pool_size).
- Создание индекса на вновь вставленных частях может быть отключено с помощью установки `materialize_skip_indexes_on_insert`. Поиск по таким частям будет возвращаться к точному поиску, но поскольку вставленные части, как правило, малы по сравнению с общим размером таблицы, влияние на производительность будет незначительным.
- ClickHouse постепенно сливает несколько частей в фоновом режиме в более крупные части. Эти новые части впоследствии могут быть снова объединены в еще более крупные части. Каждое слияние перестраивает индекс векторного сходства выходной части (как и другие индексы пропуска) каждый раз с нуля. Это потенциально приводит к неэффективной работе при создании индексов векторного сходства. Чтобы избежать этого, можно подавить создание индексов векторного сходства во время слияния, используя настройку дерева слияния
  [materialize_skip_indexes_on_merge](../../../operations/settings/merge-tree-settings.md#materialize_skip_indexes_on_merge). Это, в
  сочетании с командой [ALTER TABLE \[...\] MATERIALIZE INDEX
  \[...\]](../../../sql-reference/statements/alter/skipping-index.md#materialize-index), обеспечивает явный контроль над жизненным циклом
  индексов векторного сходства. Например, создание индекса можно отложить на периоды низкой загрузки (например, на выходные) или после значительного ввода данных.

Индексы векторного сходства поддерживают следующий тип запроса:

``` sql
WITH [...] AS reference_vector
SELECT *
FROM table
WHERE ...                       -- WHERE-клауза является необязательной
ORDER BY Distance(vectors, reference_vector)
LIMIT N
```

Чтобы выполнить поиск с использованием другого значения параметра HNSW `hnsw_candidate_list_size_for_search` (по умолчанию: 256), также известного как `ef_search` в
оригинальном [документе HNSW](https://doi.org/10.1109/TPAMI.2018.2889473), выполните запрос `SELECT` с `SETTINGS hnsw_candidate_list_size_for_search
= <value>`.

Повторные чтения из индексов векторного сходства получают выгоду от большого кеша индекса пропуска. Если необходимо, вы можете увеличить размер кеша по умолчанию
с помощью серверной настройки [skipping_index_cache_size](../../../operations/server-configuration-parameters/settings.md#skipping_index_cache_size).

**Ограничения**: Алгоритмы приближенного поиска векторов требуют ограничения, следовательно, запросы без клаузы `LIMIT` не могут использовать индексы векторного сходства. Ограничение также должно быть меньше, чем значение настройки `max_limit_for_ann_queries` (по умолчанию: 100).

**Отличия от обычных индексов пропуска**. Подобно обычным [индексам пропуска](/optimize/skipping-indexes), индексы векторного сходства строятся по гранулам и каждый индексированный блок состоит из `GRANULARITY = [N]`-числа гранул (`[N]` = 1 по умолчанию для обычных индексов пропуска). Например, если гранулярность первичного индекса таблицы составляет 8192 (настройка `index_granularity = 8192`), а `GRANULARITY = 2`, тогда каждый индексированный блок будет содержать 16384 строки. Однако структуры данных и алгоритмы для приближенного поиска соседей по своей природе ориентированы на строки. Они хранят компактное представление набора строк и также возвращают строки для запросов поиска векторов. Это приводит к некоторым довольно неинтуитивным различиям в поведении индексов векторного сходства по сравнению с обычными индексами пропуска.

Когда пользователь определяет индекс векторного сходства на колонке, ClickHouse внутренне создает "подиндекс" векторного сходства для каждого индексированного блока. Подиндекс является "локальным" в том смысле, что он знает только о строках своего содержащего индексированного блока. В предыдущем примере, если предположить, что колонка содержит 65536 строк, мы получаем четыре индексированных блока (охватывающих восемь гранул) и подиндекс векторного сходства для каждого индексированного блока. Подиндекс теоретически может вернуть строки с N ближайшими точками в пределах своего индексированного блока непосредственно. Однако, поскольку ClickHouse загружает данные с диска в память с гранулярностью гранул, подиндексы экстраполируют соответствующие строки до гранулярности гранул. Это отличается от обычных индексов пропуска, которые пропускают данные с гранулярностью индексированных блоков.

Параметр `GRANULARITY` определяет, сколько подиндексов векторного сходства будет создано. Более крупные значения `GRANULARITY` означают меньше, но больше по размеру подиндексов векторного сходства, вплоть до точки, где у колонки (или части данных колонки) остается только один подиндекс. В этом случае подиндекс имеет "глобальный" обзор всех строк колонки и может непосредственно вернуть все гранулы колонки (части) с соответствующими строками (таких гранул не более `LIMIT [N]`). На втором этапе ClickHouse загрузит эти гранулы и определит фактически лучшие строки, выполняя грубое вычисление расстояния по всем строкам гранул. При малом значении `GRANULARITY` каждый из подиндексов возвращает до `LIMIT N`-числа гранул. В результате необходимо загрузить и постфильтровать больше гранул. Обратите внимание, что точность поиска в обоих случаях одинаково хороша, отличается только производительность обработки. Обычно рекомендуется использовать большое значение `GRANULARITY` для индексов векторного сходства и возвращаться к меньшим значениям `GRANULARITY` только в случае проблем, таких как чрезмерное потребление памяти структурами векторного сходства. Если для индексов векторного сходства не было указано значение `GRANULARITY`, значение по умолчанию составляет 100 миллионов.
