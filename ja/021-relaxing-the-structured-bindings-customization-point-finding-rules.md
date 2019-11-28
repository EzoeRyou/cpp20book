## 構造化束縛のカスタマイゼーションポイントを名前検索するルールの緩和

この機能を説明する前に、まずC++17の構造化束縛のおさらいが必要だ。すでに構造化束縛について完全に理解している読者は読み飛ばしても良い。


### C++17の構造化束縛のおさらい

C++17の構造化束縛は複数の要素を持つ型から、その要素をそれぞれ名前をつけて変数に代入するコア言語機能だ。

~~~cpp
int main()
{
    int a[3] = {1,2,3} ;
    auto [a0, a1. a2] = a ;
    // a0 = a[0], a1 = a[1], a2 = a[2]
}
~~~

その文法はキーワード`auto`に続いて`[identifier1, identifier2, ...]`のように識別子のリストを書く。そして、初期化子を、`= 代入式`、もしくは`{代入式}`、もしくは`(代入式)`のように書く。代入式は配列、もしくは非unionなクラス型でなければならない。

~~~c++
int main ()
{
    int x[3] = {1,2,3} ;

    auto [a,b,c] = x ;
    auto [d,e,f] {x} ;
    auto [g,h,i] (x) ;
}
~~~

構造化束縛は、それぞれの識別子のリストを変数としてそれぞれに対応する要素を代入していく。

配列の場合は最初の識別子の変数に配列の最初の要素を、次の識別子に変数に配列の次の要素を、と代入していく。

~~~c++
int x[3] = {1,2,3} ;
auto [a,b,c] = x ;
// a = a[0], b = a[1], c = a[2]
~~~

カスタマイゼーションポイントのないクラスの場合、非staticデータメンバーを宣言順に代入していく。

~~~cpp
struct S
{
    int a, b, c ;
} ;

int main()
{
    S s = {1,2,3} ;
    auto [a,b,c] = s ;
    // a = s.a, b = s.b, c = s.c
}
~~~

カスタマイゼーションポイントは、`std::tuple_size<E>`, `std::tuple_element<i,E>`, `get<i>`の3つがある。この3つのカスタマイゼーションポイントを実装することで、ユーザー定義型を構造化束縛に対応させることができる。

C++の標準ライブラリでは、`std::pair`と`std::tuple`が対応している。

~~~cpp
int main()
{
    std::pair p = {1, 1.0} ;
    auto [a,b] = p ;
    // aはint型で値は1
    // bはdouble型で値は1.0

    std::tuple t = {1,2,3} ;
    auto [c,d,e] = t ;
    // 型はすべてint
    // c = 1, d = 2, e = 3
}
~~~

`E`を構造化束縛の初期化子の式の型とする。

~~~c++
// Eはdecltype(expr)
auto [a,b,c] = expr ;
~~~

このとき、`expr`の式を評価した結果の型、つまり`decltype(expr)`が`E`となる。

構造化束縛の要素数は`std:::tuple_size<E>::value`で指定する。ユーザーはテンプレートの特殊化や部分的特殊化で対応する。

~~~cpp
// 構造化束縛に対応させたいユーザー定義型
class UserDefinedType { } ;

template < >
struct std::tuple_size< UserDefinedType >
{
    // 構造化束縛の要素数を指定
    static constexpr std::size_t value = ... ;
} ;
~~~

構造化束縛の`i`番目の要素の型は`std::tuple_element<i, E>::type`で指定する。ユーザーはテンプレートの特殊化や部分的特殊化で対応する。

~~~cpp
// 構造化束縛に対応させたいユーザー定義型
class UserDefinedType { } ;

template  < std::size_t i >
struct std::tuple_element< i, UserDefinedType >
{
    // i番目の要素の型
    using type = ... ; 
} ;
~~~

構造化束縛の`i`番目の変数の値は`get<i>`で指定する。この`get`は関数テンプレートで第一テンプレート仮引数に非型テンプレートパラメーターを取る。この仮引数に対する実引数は、`i`番目の要素という意味で、関数テンプレートの戻り値は`i`番目の要素に対応する値を返す。

`get`テンプレートには2種類ある。Eのメンバー関数テンプレートと、ADLによって発見されるフリー関数だ。

`E`のメンバー関数テンプレートの場合、型`E`自体のメンバー関数テンプレートとして`get`を実装する。

~~~cpp
class UserDefinedType
{
public :
    template < std::size_t i >
    auto get()
    {   // i番目の要素の値を返す
        return ... ;
    }
} ;
~~~

ADLによって発見されるフリー関数の場合、`E`の連想名前空間に名前`get`の関数テンプレートを書く。テンプレート実引数は値を返すべき`i`番目の要素の`i`で、関数実引数は、構造化束縛の初期化子を評価した結果の型`E`のオブジェクトだ。

~~~cpp
// 連想名前空間はグローバル名前空間
class UserDefinedType {} ;

template < std::size_t i >
auto get( UserDefinedType & obj )
{   // i番目の要素の値を返す
    return ... ;
}
~~~

型`E`にメンバー関数テンプレート`get`があり、その第一テンプレート仮引数が非型テンプレートパラメーターの場合、メンバーの`get`が使われる。そうでない場合は、ADLによってフリー関数テンプレート`get`が探される。

以上を踏まえて、具体的に自作のクラスを構造化束縛に対応させてみよう。

今回実装するのは以下のようなクラスだ。

~~~cpp
int main()
{
    index_generator<3> i3 ;
    auto [a,b,c] = i3 ;
    // 型はすべてstd::size_t
    // a = 0, b = 1, c = 2

    index_generator<5> i5 ;
    auto [d,e,f,g,h] = i5 ;
    // 型はすべてstd::size_t
    // d = 0, e = 1, f = 2, g = 3, h = 4
}
~~~

`index_generator<I>`のオブジェクトは、構造化束縛の初期化子として使う問、I個の要素を持ち、要素の型はすべて`std::size_t`型で、`i`番目の要素の値は`i`になる。ただし、最初の要素は0番目、次の要素は`1`番目、...、最後の要素は`I-1`番目だ。

まずクラスを定義しよう。

~~~cpp
template < std::size_t >
struct index_generator { } ;
~~~

クラス定義はこれだけだ。このクラスは実際に要素をデータメンバーで持っているわけではない。本質的には空だ。構造化束縛の初期化子として使った場合に上のような挙動になるだけなので、これだけでよい。テンプレートパラメーターには名前すら付いていないが、クラスの定義内では使わないので、これでいい。

構造化束縛の要素数を指定する`std::tuple_size`のカスタマイゼーションポイントを実装する。

~~~c++
template < std::size_t I >
struct std::tuple_size< index_generator<I> >
{
    constexpr static std::size_t value = I ;
} ;
~~~

`index_generator<I>`の構造化束縛の要素数は`I`個なので、部分的特殊化で`index_generator<I>`の`I`を得て、その`I`をそのまま指定すればよい。ちなみにこのような名前空間化のテンプレートの特殊化の省略記法はC++17からの機能で、C++14以前では以下のように書かなければならなかった。

~~~c++
namespace std
{
    template < std::size_t I >
    struct tuple_size< index_generator<I> >
    {
        constexpr static size_t value = I ;
    } ;
}
~~~

もっとも、構造化束縛はC++17からの機能なので、このようなコードを書く必要はない。

構造化束縛の各要素の型を指定する`tuple_element`のカスタマイゼーションポイントを実装する。

~~~c++
template < std::size_t i, std::size_t _ > 
struct std::tuple_element< i, index_generator<_> >
{
    using type = std::size_t ;
} ;
~~~

今回の場合、型はすべて`std::size_t`型だ。そのため、`tuple_element`の部分的特殊化を書き、`index_generator`のすべての特殊化に対してネストされた型名`type`を`std::size_t`型にする。

`get<i>`を実装する方法は2つある。`E`のメンバー関数テンプレートと、フリー関数テンプレートだ。

`get<i>`をメンバー関数テンプレートで実装する。

~~~c++

template < std::size_t I >
struct index_generator
{
    template < std::size_t i >
    static constexpr auto get() { return i ; }
} ;
~~~

今回、`E`のオブジェクトは空なので、特に`this`に依存することはない。そのためstaticメンバーでもよい。`i`番目の要素の値は`i`になるので、実装は単に`i`を返すだけだ。

フリー関数テンプレートで実装する場合は以下のようになる。

~~~c++
template < std::size_t i, std::size_t _ >
auto get( index_generator<_> const & )
{
    return i ;
}
~~~

これも`i`をそのまま返せばよい。`index_generator`のオブジェクトは必要がないが、引数として受け取らなければならない。


### C++20による変更

C++20では構造化束縛のカスタマイゼーションポイント`get`を探すルールが変更される。

当初のC++17では、「構造化束縛の初期化子の型にメンバー関数`get`があった場合、メンバー関数が使われる。ない場合は、ADLにより`get`が探される」というルールになっていた。

~~~c++
struct has_get
{
    template < std::size_t I >
    auto get() ;
} ;

struct no_get
{

} ;

int main()
{
    // has_get::getが使われる
    auto[a] = has_get{} ;
    // ADLによりgetが探される
    auto[b] = no_get{} ;
}
~~~

問題は、`get`という名前のメンバー関数があった場合、それがテンプレートでなくても問答無用で使われ、ADLによる名前検索は行われない。

そこで、C++20では、たとえメンバー関数名`get`を発見した場合に、それが関数テンプレートで、かつ第一テンプレートパラメーターが非型テンプレートパラメーターである場合のみ使われ、それ以外の場合はADLによる名前探索を行うように変更された。これにより、たまたま`get`という名前のメンバー関数がある場合で、カスタマイゼーションポイントをADL経由で発見されるフリー関数で実装した場合でも、正しく動く。`get`という名前は標準ライブラリでもスマートポインターなどで使われているありふれた名前だ。衝突は十分にありえる。

~~~c++
struct A
{
    // 構造化束縛のカスタマイゼーションポイントではない
    // 理由：テンプレートではない
    int get() ;
} ;

struct B
{
    // 構造化束縛のカスタマイゼーションポイントではない
    // 理由：第一テンプレート仮引数が非型テンプレートパラメーターではない
    template < typename T >
    int get() ;
} ;
~~~

この変更はC++17にもさかのぼって適用される。

