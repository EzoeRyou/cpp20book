## destroying operator delete

C++20にはdestroying operator delete(解放するoperator delete)が追加された。これはクラスのメンバーとしてのoperator deleteの演算子オーバーロードで以下のような形になる。

~~cpp
struct A
{
    void operator delete( A *, std::destroying_delete_t ) ;
} ;

struct B
{
    void operator delete( void *, std::destroying_delete_t ) ;
} ;
~~~

destroying operator deleteの第一引数は、メンバーであるクラスへのポインター、もしくは`void *`、第二引数は`std::destroying_delete_t`型となる。

第二引数は単にdestroying operator deleteを区別するためのタグ型で、以下のように定義されている。

~~~c++
namespace std {
    struct destroying_delete_t {
        explicit destroying_delete_t() = default ;
    } ;
    inline constexpr destroying_delete_t destroying_delete{} ;
}
~~~

`std::destroying_delete_t`がdestroying operator deleteの第二引数に使う型で、`std::destroying_delete`はdestroying operator deleteを明示的に呼び出したいときに使える`std::destroying_delete_t`型の便利な値だ。

~~~c++
struct S
{
    void operator delete( S *, std::destroying_delete_t ) ;
} ;

void f( S * p )
{
    S::operator delete( p, std::destroying_delete ) ;
}
~~~

クラスのメンバーとしてのdestroying operator deleteのオーバーロードは、従来のoperator deleteのメンバーでのオーバーロードとは決定的に異なる点がある。

従来のoperator deleteに渡されるポインターの型はvoid *で、これはすでにデストラクターが呼び出されオブジェクトは破棄された後の生のストレージへの先頭のポインターとなっている。operator deleteが行うのは、生のストレージの解放処理だ。デストラクターの呼び出しをする責任はない。それはコンパイラーが行う。

~~~cpp
struct S
{
    void * operator new( std::size_t size )
    {
        // 生のストレージへのポインターを返す
        // コンストラクター呼び出しをする責任はない
        return ::operator new( size ) ;
    }

    void operator delete( void * ptr )
    {
        // 生のストレージを解放する。
        // ptrはすでに破棄されている
        // デストラクター呼び出しをする責任はない
        ::operator delete( ptr ) ;
    }

    // デストラクター
    ~S() { }
} ;
~~~

C++20で追加されたdestroying operator deleteでは、オブジェクトは破棄されないまま渡される。destorying operator deleteはデストラクター呼び出しをする責任を持つ。

~~~cpp
struct S
{
    void * operator new( std::size_t size )
    {
        return ::operator new( size ) ;
    }
    
    void operator delete( S * ptr, std::destroying_delete_t )
    {
        // デストラクター呼び出しをする責任を持つ 
        ptr->~S() ;
        // 生のストレージの解放
        ::operator delete( ptr ) ;
    }

    // デストラクター
    ~S(){}
} ;
~~~

そのため、destroying operator deleteの第一引数は`void *`の他にクラスへのポインター型でもよい。`void *`型の場合でも参照先のオブジェクトは破棄されていないので、destroing operator deleteはデストラクター呼び出しに責任を持つ必要がある。

~~~cpp
struct S
{
    void operator delete( void * ptr, std::destroying_delete_t )
    {
        // デストラクター呼び出し
        auto s_ptr = reinterpret_cast<S *>(ptr) ;
        s:ptr->~S() ;

        // 生のストレージの解放処理
    }
} ;
~~~

解放関数のオーバーロードが複数ある場合のオーバーロード解決については、destroying operator deleteが最も優先される。

~~~cpp
void operator delete( void * ) ;

struct S
{
    void operator delete( void * ) ;
    void operator delete( S *, std::destroying_delete_t ) ;
} ;
~~~

このような型Sへのポインターをdeleteした場合、destroying operator deleteが呼ばれる。

配列のdeleteにおいてdestroying operator deleteが使われることはない。

### 応用

この機能が追加された需要を直接学ぶことで、この機能の応用例について学ぶ。

inline_fixed_stringというクラスを考える。このクラスは文字列クラスなのだが、ストレージの確保方法が変わっている。ストレージはオブジェクトが構築されたストレージの直後に存在する。


~~~c++
// 10文字分のnull終端されていない文字列
char buf[ sizeof(inline_fixed_string) + 10] ;
// オブジェクトの構築
inline_fixed_string * ptr = new(buf)(10) ;
~~~

このクラスがinlineなのは文字列を格納するためのストレージがオブジェクトに後続しているためで、fixedなのは文字列を格納するストレージが固定されているためだ。

このようなinline_fixed_stringの実装例をみてみよう。

~~~c++
// 文字列クラス
// ただし文字列を保持するストレージは
// オブジェクトが構築されているストレージの直後に続く
struct inline_fixed_string
{
    inline_fixed_string( std::size_t size )
        : size_(size) { }
    std::size_t size() const
    { return size_ ; }

    // 文字列アクセス
    char & operator []( std::size_t i )
    {
        reinterpret_cast<char *>(this + 1)[i] ;
    }

    // 指定の文字数でクラスのオブジェクトをnewするヘルパー関数
    static inline_fixed_string * make( std::size_t size )
    {
        void * raw_ptr = ::operator new( sizeof(inline_fixed_string) + size ) ;
        return new(p)( size ) ;
    }
    std::size_t size_ ;
} ;
~~~

この実装では、inline_fixed_string::make(size)というヘルパー関数を呼び出すことで、クラスのオブジェクトと指定の文字数分の動的ストレージをまとめて確保し、かつストレージ上にinline_fixed_stringクラスの構築まで行うことができる。

~~~c++
// 動的ストレージを確保しクラスを構築
auto ptr = inline_fixed_string::make(10) ;
~~~

このように動的に構築されたクラスを破棄するにはどうすればいいだろう。手動で破棄するには、クラスのデストラクターを呼び出した後に、生のストレージを解放する。

~~~c++
// デストラクターの明示的呼び出し
ptr->~inline_fixed_string() ;
// 生のストレージの解放
::operator delete( ptr ) ;
~~~

C++にはsized deallocateという機能がある。これは解放関数(deallocation function)にストレージのサイズをヒントとして渡すことで、メモリアロケーターの実装次第では効率的なストレージの解放処理を期待するものだ。効率のためにはsized deallocateを使いたい。

~~~c++
// 生のストレージのサイズ
std::size_t raw_storage_size = sizeof(inline_fixed_string) + ptr->size() ;
// デストラクターの明示的呼び出し
ptr->~inline_fixed_string() ;
// sized deallocate
::operator delete( ptr, raw_storage_size ) ;
~~~

このような処理をクラス外で手動で書くのは面倒であるし間違いの元なので、クラス内で実装したい。makeと同じようにstaticメンバー関数として上と同じ処理を実装する方法もある。

~~~c++
// ヘルパー関数としての実装
inline_fixed_string::unmake( ptr ) ;
~~~

しかしこのような特殊な解放方法をユーザーに教育して使わせるのは難しい。できれば通常のdeleteが動いてほしい。

~~~c++
// これが動いてほしい
delete ptr ;
~~~

これを実装するにはoperator deleteをオーバーロードする。

~~~c++
struct inline_fixed_string
{
    void operator delete( void * ptr )
    {
        ::operator delete( ptr ) ;
    }
} ;
~~~

これは動く。ただし、この実装はsized deallocateを使っていない非効率的な実装だ。ではsized deallocateのオーバーロードを追加してやればいいのではないかと思うだろうが、それではうまくいかない。

~~~c++
struct inline_fixed_string
{
    void operator delete( void * ptr, std::size_t size )
    {
        // 実装方法がない
    }
} ;
~~~

なぜならば、この解放関数は、`operator delete( ptr, sizeof(inline_fixed_string))`のように呼ばれるからだ。size引数はsizeof(inline_fixed_string)であって、生のストレージの本当のサイズではない。C++コンパイラーは構築済みのクラスのサイズについては把握しているが、その直後に付属する生のストレージのサイズについては把握できないからだ。

operator deleteのオーバーロードの責任は生のストレージを解放することだけだ。operator deleteのオーバーロードが呼ばれるとき、すでにクラスのオブジェクトのデストラクターは呼ばれている。すでに解放されているオブジェクトのメンバーにアクセスすることはできない。クラスのオブジェクトのsizeにアクセスできなければ、生のストレージの本当のサイズはわからない。

そこでC++20で追加されたdestroying operator delete(解放するoperator delete)の出番だ。destroying operator deleteに渡されるクラスへのポインターはデストラクターが呼ばれていない。つまりオブジェクトはまだ破棄されていないので、合法的にメンバーにアクセスすることができる。デストラクターを呼ぶのもdestroying operator deleteの責任になる。

destroying operator deleteを使えば以下のように実装できる。

~~~c++
struct inline_fixed_string
{
    void operator delete( inline_fixed_string * ptr, std::size_t size )
    {
        // 生のストレージのサイズ
        std::size_t raw_storage_size = sizeof(inline_fixed_string) + ptr->size() ;
        // デストラクターの明示的呼び出し
        ptr->~inline_fixed_string() ;
        // sized deallocate
        ::operator delete( ptr, raw_storage_size ) ;
    }
} ;
~~~

これで、ユーザーは単に`delete ptr ;`するだけでクラスオブジェクトを破棄し、生のストレージも効率的に解放できるようになる。

機能テストマクロ：`__cpp_impl_destroying_delete >= 201806`
