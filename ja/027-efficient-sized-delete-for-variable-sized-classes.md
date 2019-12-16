## destroying operator delete

C++20にはdestroying operator deleteが追加された。これはクラスのメンバーとしてのoperator deleteの演算子オーバーロードで以下のような形になる。

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

以下のようなクラスを考える。

~~~c++
~~~
