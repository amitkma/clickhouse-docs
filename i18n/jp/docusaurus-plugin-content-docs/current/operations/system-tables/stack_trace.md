---
description: "サーバースレッドのすべてのスタックトレースを含むシステムテーブル。開発者がサーバーの状態を調査できるようにします。"
slug: /operations/system-tables/stack_trace
title: "system.stack_trace"
keywords: ["system table", "stack_trace"]
---

import SystemTableCloud from '@site/i18n/jp/docusaurus-plugin-content-docs/current/_snippets/_system_table_cloud.md';

<SystemTableCloud/>

すべてのサーバースレッドのスタックトレースを含みます。開発者がサーバーの状態を調査できるようにします。

スタックフレームを分析するには、`addressToLine`、`addressToLineWithInlines`、`addressToSymbol`、および `demangle` の [イントロスペクション関数](../../sql-reference/functions/introspection.md) を使用します。

カラム:

- `thread_name` ([String](../../sql-reference/data-types/string.md)) — スレッド名。
- `thread_id` ([UInt64](../../sql-reference/data-types/int-uint.md)) — スレッド識別子。
- `query_id` ([String](../../sql-reference/data-types/string.md)) — [query_log](../system-tables/query_log.md) システムテーブルから実行中のクエリに関する詳細を取得するために使用できるクエリ識別子。
- `trace` ([Array(UInt64)](../../sql-reference/data-types/array.md)) — 呼び出されたメソッドが格納されている物理アドレスのリストを表す [スタックトレース](https://en.wikipedia.org/wiki/Stack_trace)。

:::tip
便利なクエリについては、ナレッジベースをチェックしてください。特に、[現在実行中のスレッドを確認する方法](/knowledgebase/find-expensive-queries) や [トラブルシューティングのための便利なクエリ](/knowledgebase/useful-queries-for-troubleshooting) が含まれています。
:::

**例**

イントロスペクション関数を有効にする:

``` sql
SET allow_introspection_functions = 1;
```

ClickHouseのオブジェクトファイルからシンボルを取得する:

``` sql
WITH arrayMap(x -> demangle(addressToSymbol(x)), trace) AS all SELECT thread_name, thread_id, query_id, arrayStringConcat(all, '\n') AS res FROM system.stack_trace LIMIT 1 \G;
```

``` text
Row 1:
──────
thread_name: QueryPipelineEx
thread_id:   743490
query_id:    dc55a564-febb-4e37-95bb-090ef182c6f1
res:         memcpy
large_ralloc
arena_ralloc
do_rallocx
Allocator<true, true>::realloc(void*, unsigned long, unsigned long, unsigned long)
HashTable<unsigned long, HashMapCell<unsigned long, char*, HashCRC32<unsigned long>, HashTableNoState, PairNoInit<unsigned long, char*>>, HashCRC32<unsigned long>, HashTableGrowerWithPrecalculation<8ul>, Allocator<true, true>>::resize(unsigned long, unsigned long)
void DB::Aggregator::executeImplBatch<false, false, true, DB::AggregationMethodOneNumber<unsigned long, HashMapTable<unsigned long, HashMapCell<unsigned long, char*, HashCRC32<unsigned long>, HashTableNoState, PairNoInit<unsigned long, char*>>, HashCRC32<unsigned long>, HashTableGrowerWithPrecalculation<8ul>, Allocator<true, true>>, true, false>>(DB::AggregationMethodOneNumber<unsigned long, HashMapTable<unsigned long, HashMapCell<unsigned long, char*, HashCRC32<unsigned long>, HashTableNoState, PairNoInit<unsigned long, char*>>, HashCRC32<unsigned long>, HashTableGrowerWithPrecalculation<8ul>, Allocator<true, true>>, true, false>&, DB::AggregationMethodOneNumber<unsigned long, HashMapTable<unsigned long, HashMapCell<unsigned long, char*, HashCRC32<unsigned long>, HashTableNoState, PairNoInit<unsigned long, char*>>, HashCRC32<unsigned long>, HashTableGrowerWithPrecalculation<8ul>, Allocator<true, true>>, true, false>::State&, DB::Arena*, unsigned long, unsigned long, DB::Aggregator::AggregateFunctionInstruction*, bool, char*) const
DB::Aggregator::executeImpl(DB::AggregatedDataVariants&, unsigned long, unsigned long, std::__1::vector<DB::IColumn const*, std::__1::allocator<DB::IColumn const*>>&, DB::Aggregator::AggregateFunctionInstruction*, bool, bool, char*) const
DB::Aggregator::executeOnBlock(std::__1::vector<COW<DB::IColumn>::immutable_ptr<DB::IColumn>, std::__1::allocator<COW<DB::IColumn>::immutable_ptr<DB::IColumn>>>, unsigned long, unsigned long, DB::AggregatedDataVariants&, std::__1::vector<DB::IColumn const*, std::__1::allocator<DB::IColumn const*>>&, std::__1::vector<std::__1::vector<DB::IColumn const*, std::__1::allocator<DB::IColumn const*>>, std::__1::allocator<std::__1::vector<DB::IColumn const*, std::__1::allocator<DB::IColumn const*>>>>&, bool&) const
DB::AggregatingTransform::work()
DB::ExecutionThreadContext::executeTask()
DB::PipelineExecutor::executeStepImpl(unsigned long, std::__1::atomic<bool>*)
void std::__1::__function::__policy_invoker<void ()>::__call_impl<std::__1::__function::__default_alloc_func<DB::PipelineExecutor::spawnThreads()::$_0, void ()>>(std::__1::__function::__policy_storage const*)
ThreadPoolImpl<ThreadFromGlobalPoolImpl<false>>::worker(std::__1::__list_iterator<ThreadFromGlobalPoolImpl<false>, void*>)
void std::__1::__function::__policy_invoker<void ()>::__call_impl<std::__1::__function::__default_alloc_func<ThreadFromGlobalPoolImpl<false>::ThreadFromGlobalPoolImpl<void ThreadPoolImpl<ThreadFromGlobalPoolImpl<false>>::scheduleImpl<void>(std::__1::function<void ()>, Priority, std::__1::optional<unsigned long>, bool)::'lambda0'()>(void&&)::'lambda'(), void ()>>(std::__1::__function::__policy_storage const*)
void* std::__1::__thread_proxy[abi:v15000]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ThreadPoolImpl<std::__1::thread>::scheduleImpl<void>(std::__1::function<void ()>, Priority, std::__1::optional<unsigned long>, bool)::'lambda0'()>>(void*)
```

ClickHouseソースコードのファイル名と行番号を取得する:

``` sql
WITH arrayMap(x -> addressToLine(x), trace) AS all, arrayFilter(x -> x LIKE '%/dbms/%', all) AS dbms SELECT thread_name, thread_id, query_id, arrayStringConcat(notEmpty(dbms) ? dbms : all, '\n') AS res FROM system.stack_trace LIMIT 1 \G;
```

``` text
Row 1:
──────
thread_name: clickhouse-serv

thread_id: 686
query_id:  cad353e7-1c29-4b2e-949f-93e597ab7a54
res:       /lib/x86_64-linux-gnu/libc-2.27.so
/build/obj-x86_64-linux-gnu/../src/Storages/System/StorageSystemStackTrace.cpp:182
/build/obj-x86_64-linux-gnu/../contrib/libcxx/include/vector:656
/build/obj-x86_64-linux-gnu/../src/Interpreters/InterpreterSelectQuery.cpp:1338
/build/obj-x86_64-linux-gnu/../src/Interpreters/InterpreterSelectQuery.cpp:751
/build/obj-x86_64-linux-gnu/../contrib/libcxx/include/optional:224
/build/obj-x86_64-linux-gnu/../src/Interpreters/InterpreterSelectWithUnionQuery.cpp:192
/build/obj-x86_64-linux-gnu/../src/Interpreters/executeQuery.cpp:384
/build/obj-x86_64-linux-gnu/../src/Interpreters/executeQuery.cpp:643
/build/obj-x86_64-linux-gnu/../src/Server/TCPHandler.cpp:251
/build/obj-x86_64-linux-gnu/../src/Server/TCPHandler.cpp:1197
/build/obj-x86_64-linux-gnu/../contrib/poco/Net/src/TCPServerConnection.cpp:57
/build/obj-x86_64-linux-gnu/../contrib/libcxx/include/atomic:856
/build/obj-x86_64-linux-gnu/../contrib/poco/Foundation/include/Poco/Mutex_POSIX.h:59
/build/obj-x86_64-linux-gnu/../contrib/poco/Foundation/include/Poco/AutoPtr.h:223
/lib/x86_64-linux-gnu/libpthread-2.27.so
/lib/x86_64-linux-gnu/libc-2.27.so
```

**参照**

- [イントロスペクション関数](../../sql-reference/functions/introspection.md) — 使用できるイントロスペクション関数とその使い方。
- [system.trace_log](../system-tables/trace_log.md) — サンプリングクエリプロファイラーによって収集されたスタックトレースを含む。
- [arrayMap](/sql-reference/functions/array-functions#arraymapfunc-arr1-) — `arrayMap` 関数の説明と使用例。
- [arrayFilter](/sql-reference/functions/array-functions#arrayfilterfunc-arr1-) — `arrayFilter` 関数の説明と使用例。
