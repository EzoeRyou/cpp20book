## 非型テンプレート仮引数の制限緩和

C++20では非型テンプレート仮引数の実引数として浮動小数点数型やクラス型を渡せるようになった。

~~~cpp
template < auto value >
struct A { } ;

struct B { } ;

int main()
{
    A<1.0> a1 ;
    A<B{}> a2 ;
}
~~~

クラス型であればどのようなクラスでも渡せるわけではない。テンプレート仮引数はテンプレートの同一性を比較できる必要があるため、強い制約がある。

### 非型テンプレート仮引数の型

非型テンプレート仮引数には、大きく分けて3種類の型を使うことができる。

+ 構造型(structual type)
+ placeholder型を含む型
+ 推定されるクラス型のプレイスホルダー

構造型(structual type)については後述する。

このうち、placeholder型というのはC++17で非型テンプレート仮引数にも使えるようになった機能で、`auto`と`decltype(auto)`のことだ。

~~~cpp
template < auto value >
struct A { } ;
template < decltype(auto) value >
struct B { } ;

int main()
{
    // valueの型はint
    A<123> a ;
    // valueの型はint
    B<123> b ;
}
~~~

placeholder型を含む型というのは、例えばCV修飾子やリファレンス修飾子を使えるということだ。

~~~cpp
template < const auto & value >
struct A { } ;
~~~

`auto`と`decltype(auto)`の違いを簡単に説明すると、`auto`はテンプレート実引数推定のルールにしたがって型を推定するのに対し、`decltype(auto)`は初期化子の式をdecltypeの中に書いたかのように振る舞う。

~~~c++
auto x = expr ;
~~~

この変数xの型は、あたかも、

~~~c++
template < typename T >
void f( T ) ;

f( expr ) ;
~~~

としたときのテンプレート仮引数Tと同じ型になる。

一方、`decltype(auto)`の場合、

~~~c++
decltype(auto) x = expr ;
~~~

これは`auto`部分を`expr`で置き換えたかのように振る舞う。つまり、以下のコードと同じ意味になる。

~~~c++
decltype(expr) x = expr ;
~~~

推定されるクラス型のプレイスホルダーというのは、クラスのコンストラクターからのテンプレート実引数推定のことだ。

~~~cpp
template < typename T >
struct A { } ;

// 推定されるクラス型のプレイスホルダーA
template < A a >
struct B { } ;

int main()
{
    // コンストラクターからA<int>が推定される
    B< A<int>{} > b ;
}
~~~

#### 構造型(structural type)

C++17までは、非型テンプレート仮引数の値の型は整数型、ポインター型、lvalueリファレンス型しか許されていなかった。C++20ではこの制限が大幅に緩和された。非型テンプレート仮引数の値には構造型(structural type)を渡せる。

構造型(structural type)とは以下のように定義される。

+ スカラー型
+ lvalueリファレンス型
+ リテラルクラス型かつ以下の特性を持つもの
    + すべての基本クラスと非staticデータメンバーはpublicでmutableではない
    + すべての基本クラスと非staticデータメンバーは構造型もしくはその配列（多次元配列も可）である。

#### スカラー型

スカラー型(scalar types)とは、演算型(arithmetic types)、enum型、ポインター型、メンバーへのポインター型、std::nullptr_t型、それらの型のCV修飾版の型のことだ。

演算型とは整数型と浮動小数点数型のことだ。

C++20ではスカラー型がすべて非型テンプレート仮引数の値の型として使えるようになったので、浮動小数点数を使うことができる。

~~~c++
template < double value >
struct S { } ;

// OK
using type = S<1.0> ;
~~~

#### lvalueリファレンス型

非型テンプレート仮引数の値がlvalueリファレンス型のとき、実引数として取れるのはstaticストレージ上に構築された値だ。

~~~c++
template < int & ref >
struct S {  } ;

// 名前空間スコープの変数はstaticストレージ上に構築される
int static_storage { } ;

int main()
{
    // 関数のローカル変数はautomatic storage上に構築される
    int automatic_storage{} ;
    // エラー
    S< automatic_storage > s1{} ;


    // OK    
    S< static_storage > s2 { } ;
    // static指定子つきのローカル変数はstaticストレージ上に構築される
    static int static_locale_storage{} ;
    // OK
    S< static_local_storage > s3{} ;
}
~~~

#### 条件付きリテラルクラス型

以下のような条件のリテラルクラス型は非型テンプレート仮引数の値にできる。

+ リテラルクラス型かつ以下の特性を持つもの
    + すべての基本クラスと非staticデータメンバーはpubliでmutableではない
    + すべての基本クラスと非staticデータメンバーは構造型もしくはその配列（多次元配列も可）である。

リテラルクラス型は以下のように定義されている。

+ CV修飾されているものを含むクラス型で、以下のすべての特性を持つもの
    + constexprデストラクターを持つ
    + クロージャー型、もしくはアグリゲート型、もしくは少なくとも1つのconstexprコンストラクターかコンストラクターテンプレート（基本クラスから継承したものでもよい）でコピー、ムーブコンストラクターではないもの
    + union型である場合、非staticメンバーのうちの少なくとも1つは非volatileリテラル型であること
    + union型ではない場合、すべての非staticデータメンバーと基本クラスは非volatileリテラル型であること




### テンプレート実引数同一

2つのテンプレートIDが同一であるかということは重要だ。

型テンプレート仮引数の場合、テンプレート実引数が同じ型であれば同じテンプレートIDだ。

~~~cpp
tempplate < typename T >
struct S { }

using T1 = S<int *> ;
using T2 = S< std::add_pointer_t<int> > ;
// true
constexpr bool b = std::is_same_v< T1, T2 > ;
~~~

この場合、T1とT2は同じ型になる。

非型テンプレート仮引数の場合も、テンプレート実引数が同じ型で同じ値であれば同じテンプレートIDという原則は変わらない。ただし、「同じ値」ということについては、通常とは違う特別な定義されている。

値がクラス型の場合、`operator ==`、`operator !=`, `operator <=>`は考慮されない。

C++の規格は、以下のように定義している。

2つの値は同じ型で以下の条件を満たす場合、テンプレート実引数同一(template-argument-equivalent)である。

+ 整数型で、その値が同じ
+ 浮動小数点数型で、その値は同一
+ `std::nullptr_t`型である
+ enum型Tで、その値が同じ
+ ポインター型で同じポインター値を持つ
+ メンバーへのポインター型で同じクラスメンバーを指す、もしくはどちらもnullメンバーポインター値である
+ リファレンス型で、同じオブジェクトもしくは関数を指す
+ 配列型で、対応する要素はそれぞれテンプレート実引数同一性を満たす
+ union型で、どちらもアクティブメンバーを持たないか、同じアクティブメンバーを持ち、そのアクティブメンバーがテンプレート実引数同一を満たす
+ クラス型で、対応するそれぞれの直接のサブオブジェクトとリファレンスメンバーがテンプレート実引数同一を満たす

いくつか注意すべき点がある。

浮動小数点数は値が同じでも同一ではない可能性がある。例えば最も普及しているIEEE 754規格の浮動小数点数の場合、`+0.0`と`-0.0`は値は同じだが同一ではない。

~~~cpp
template < auto > struc S { } ;

int main()
{
    // true
    bool a = (+0.0 == -0.0) ;
    // false
    bool b = std::is_same_v< S<+0.0>, S<-0.0> > ;
}
~~~

なぜならば浮動小数点数の表現としては同一ではないからだ。

~~~cpp
int main()
{
    double a = +0.0 ;
    double b = -0.0 ;
    // 非ゼロ、同じバイト列ではない
    auto result = std::memcmp( &a, &b, sizeof(
}
~~~

enum型はその値で比較される。列挙子の違いは考慮されない。

~~~cpp
enum struct E{ a = 1, b = 1 } ;
template < auto > struct S ;

int main()
{
    // true
    bool b = std::is_same_v< S<E::a>, S<E::b> > ;
}
~~~

リファレンスは同じオブジェクトを参照している場合に同一とみなされる。同じ値の異なるオブジェクトへの参照は同一ではない。

~~~cpp
template < int & > struct S { } ;

int main()
{
    static int a = 1 ;
    static int b = 1 ;
    // false
    bool b = std::is_same_v< S<a>, S<b> > ;
}
~~~

非型テンプレート仮引数に配列型を使うと、それは配列の要素型へのポインター型になる。

~~~cpp
// < int * >と同じ
template < int A[5] > struct S { } ;

int main()
{
    static int a[5] ;
    // S< &a[0] >と同じ
    using type = S<a> ;
}
~~~

配列のテンプレート実引数同一は、クラスのデータメンバーとして使ったときに考慮される。

~~~cpp
struct Array
{
    int data[5] ;
} ;

template < Array > struct S { } ;

constexpr Array a = {{1,2,3,4,5}} ;
constexpr Array b = {{1,2,3,4,5}} ;
constexpr Array c = {{6,7,8,9,0}} ;

using A = S<a> ;
using B = S<b> ;
using C = S<c> ;
~~~

ここで、AとBは同じ型だが、CはA, Bとは違う別の型だ。


