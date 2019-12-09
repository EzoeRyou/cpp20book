## Range-based forのカスタマイゼーションポイントの検索方法の変更

以下のようなRange-based forは、

~~~c++
for (初期化文 宣言 : 式 ) 文
~~~

以下のように変形される。

~~~c++
{
    初期化文
    auto && range = 式
    auto begin = begin-expr ;
    auto end = end-expr ;
    for ( ; begin != end ; ++begin ) {
        宣言 = * begin ;
        文
    }
}
~~~

具体的に書くと、以下のようなコード

~~~c++
for ( auto r = f() ; auto i : r )
    g(i)
~~~

のようなコードは

~~~c++
{
    auto r = f() ;
    auto && range = r ;
    auto begin = begin-expr ;
    auto end = end-expr ;
    for ( ; begin != end ; ++begin ) {
        auto i = * begin ;
        g(i) ;
    }
        
}
~~~

のようになる。

ここで、`begin-expr`と`end-expr`が具体的にどういう式になるかは、`range`の型によって変わる。

C++17ではおおむね以下のようなルールになっている。

1. rangeの型が配列の場合、`begin-expr`は`range`、`end-expr`は`range + N`となる。Nは配列の要素数
2. rangeの型がクラスで、メンバー関数にbegin/endの*いずれか*があった場合、 `begin-expr`は`range.begin()`、`end-expr`は`range.end()`となる
3. それ以外の場合、`begin-expr`は`begin(range)`、`end-expr`は`end(range)`となる。ここで`begin`と`end`はADLによって名前検索される

このとき、`begin`と`end`のことをカスタマイゼーションポイント(customization point)という。`begin`と`end`をユーザーが書くことで、クラスをrange-based forに対応させることができる。対応させるためのカスタマイズができるポイントなのでカスタマイゼーションポイントという。

C++17のルールには不備がある。具体的には2番めのルールのうちの「メンバー関数にbegin/endの*いずれか*があった場合」というところだ。

あるクラスに`begin`か`end`という名前のメンバー関数が片方だけあった場合でも、メンバー関数がカスタマイゼーションポイントとして使われてしまう。

~~~c++
namespace library {

struct S
{
    // たまたま名前がかぶっただけの
    // イテレーターを返すわけではない
    // 別の目的のメンバー関数
    void begin() ;
} ;

// イテレーターを返すカスタマイゼーションポイント
auto begin( S & ) ;
auto end( S & ) ;

}

int main()
{
    library::S s ;
    // エラー
    // s.end()は見つからない
    for ( auto i : s )
        do_somethign(i) ;
         
}
~~~

このため、C++20では、2番めのルールに変更が加えられた。


2. rangeの型がクラスで、メンバー関数にbegin/endの*両方*があった場合、 `begin-expr`は`range.begin()`、`end-expr`は`range.end()`となる

2番目のルールは`begin/end`の両方のメンバー関数が同時に存在した場合のみ使われる。もしクラスに`begin`, `end`両方のメンバー関数がない場合は、3番目のルールであるADLによるカスタマイゼーションポイントが使われる。
