## [[no_unique_address]]: 空のオブジェクトの言語サポート

[[no_unique_address]]は非staticデータメンバーのサイズをゼロにするための属性だ。

~~~cpp
struct A {} ;
struct B {} ;

struct C
{
    [[ no_unique_address ]] A a ;
    [[ no_unique_address ]] B b ;
} ;

// 1でもよい
std::size_t s = sizeof(C) ;
~~~

この場合、`&C::a`と`&C::b`の値が違う保証はない。

[[no_unique_address]]を使っても、元々非ゼロのサイズを持つクラスのオブジェクトのサイズがゼロになるわけではない。

~~~cpp
struct A { int data ;} ;
struct B { int data ; } ;

struct C
{
    [[ no_unique_address ]] A a ;
    [[ no_unique_address ]] B b ;
} ;

// sizeof(int)*2以上
std::size_t s = sizeof(C) ;
~~~

また、たとえサイズをゼロにできる型であったとしても、同じ型を複数回使った場合は、サイズはゼロにならない。

~~~cpp
struct A { } ;
struct B
{
    [[ no_unique_address ]] A a1 ;
    [[ no_unique_address ]] A a2 ;
} ;

// 2以上
std::size_t s = sizeof(B) ;
~~~

同じ型の異なるオブジェクトを区別できるようにするためだ。

ビットフィールドには適用できない。

~~~c++
struct S
{
    // エラー
    [[no_unique_address]] int x:3 ;   
} ;
~~~

なぜこのような機能が追加されたのか

C++では、すべてのオブジェクトは非ゼロのサイズを持っている。非staticデータメンバーを持たず、virtual関数も持たない空のクラスであっても、そのサイズは1以上ある。

~~~cpp
struct empty { } ;

// 1以上
std::size_t s = sizeof(empty) ;
~~~

この理由は、オブジェクトのアドレスを得るためと、配列のためだ。

~~~cpp
struct empty { } ;

int main()
{
    empty e;
    // アドレスを得る
    empty * p = &e ;
    // 配列
    empty a[10] ;

    // false
    bool b = (a + 3) == (a + 5)
}
~~~

オブジェクトが本質的に空であっても、1以上のサイズを持つということは、そのようなオブジェクトを複数もつクラスは、オブジェクトの個数だけ無駄にサイズが増えることを意味する。本質的に空であれば、そのようなオブジェクトを持たなければいいのではないかと考えるかも知れない。しかし、場合によってはオブジェクトを持たざるを得ない場合もある。

例えば、何らかのデータ構造で多数の値を管理するコンテナークラスを考える。このコンテナークラスはデータ構造のために、要素同士の比較と、要素のハッシュ値を必要とする。そのための処理はユーザーが関数オブジェクトとして提供する。

~~~cpp
template <
    typename T,         // 要素型
    typename Compare,   // 要素同士の比較
    typename Hasher >    // 要素のハッシュ値
struct Container
{
    Compare c ;
    Hasher h ;

    T * ptr ;

    Container( Compare c, Hasher h )
        c(c), h(h) { }
} ;
~~~

ここで、比較をするCompareやハッシュ値計算をするHasherは、本質的に空のオブジェクトかも知れない。

~~~cpp
struct compare
{
    bool operator ()( auto const & a, auto const & b ) const ;
} ;

struct hasher
{
    unsigned int operator() ( auto const & obj ) const ;
} ;
~~~

しかしオブジェクトのサイズは少なくとも1は必要だ。すると先程のContainerクラスのデータメンバーc, hがそれぞれ1のサイズを持つとすると、クラス全体のサイズは少なくとも2バイト増えることになる。しかし現実には、クラスのサイズ増加はさらに大きい。

筆者の環境では、以下のコードのサイズは16だ。

~~~cpp
// 筆者の環境では16
std::size_t size = sizeof( Container<int, compare, hasher> ) ;
~~~

これはなぜか。筆者の環境では、`sizeof(int *)`は`8`だ。筆者の環境では`alignof(int *)`は8なので、ptrは8バイトにアライメントされていなければならない。Containerクラスの配列が8バイトにアライメントされるためには、Containerクラスは少なくとも16バイトのサイズを持っていなければならないことになる。そのために6バイトのパディングバイトが発生する。

この問題を回避するために、慣習的にEBO(Empty Base Optimization、空の基本クラス最適化)というコンパイラーの最適化を利用する技法が使われていた。これはC++の標準規格でも許されている最適化のための挙動だ。

EBOとは、「基本クラスが空ならば、そのためにクラスのメモリーレイアウトで専用のストレージを確保しなくてもよい」というルールだ。


~~~cpp
struct A { } ;
struct B : A { } ;
struct C : B  { } ;

// 1でもよい
std::size_t size = sizeof(C) ; 
~~~

クラスAは本質的に空で、クラスBも同様に空だ。するとクラスCは基本クラスの分をストレージをクラスのメモリーレイアウトに含めなくてもよい。

[[no_unique_address]]はEBOのような最適化を非staticデータメンバーにも提供する。

サイズを0にできる本質的に空のクラスとは何か。これは実装依存だ。どのようなクラスが本質的に空でありサイズを0にできるかは実装により異なる。

1つの目安としては、空ではない非staticデータメンバーがなく、空ではない基本クラスもなく、virtual関数もないクラスは、空になる可能性が高い。

もし本質的に空のオブジェクトであるデータメンバーc, hがオブジェクトとしてのサイズを持たなければ、Containerクラスが本質的に必要なのはポインターひとつ分のサイズだけだ。そこで、[[no_unique_address]]の出番となる。

[[no_unique_address]]はクラスの非staticデータメンバーの宣言に使うことができる。この属性が使われたデータメンバーのオブジェクトが空であり、サイズをゼロにできるとき、クラスのサブオブジェクトとしてのサイズがゼロになる。そのようなデータメンバーのアドレスは他のデータメンバーのアドレスと異なる保証はない。


