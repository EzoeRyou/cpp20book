## ラムダキャプチャーの中のパック展開

ラムダキャプチャーはパラメーターパックをパック展開しながらキャプチャーできるようになった。


~~~cpp
template < typename ... Types >
void take_all( Types &&  ... ) { }

template < typename ... Types >
void f( Types && ... args )
{
    [ args...]{ take_all( args... ) ;} ;
}
~~~

### 単純キャプチャー

単純キャプチャーの場合は、キャプチャーの直後に`...`を書く。

~~~cpp
template < typename ... Types >
void f( Types &&* ... pack )
{
    // コピーキャプチャー
    [pack...]{} ;
    // リファレンスキャプチャー
    [&pack...{} ;]
}
~~~

### 初期化キャプチャー

初期化キャプチャーの場合は、キャプチャーの直前に`...'を書く。

~~~cpp
template < typename ... Types >
void f( Types && ... pack )
{
    // 初期化キャプチャーによるコピー
    [...values = pack ]{} ;
    // 初期化キャプチャーによるムーブ
    //
    [...values = std::move(pack){} ;
}
~~~
