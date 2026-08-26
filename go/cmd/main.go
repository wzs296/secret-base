package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"fmt"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	// 演示并发通道通信
	//ChannelCommunication()
	//ChannelWithBufferCommunication()
	//mutexDemo()
	//AtomicAdd()
	message := "hello world"
	secret := []byte("my-secret-key")

	h := hmac.New(sha256.New, secret)
	h.Write([]byte(message))
	signature := h.Sum(nil)

	fmt.Printf(" 消息: \"%s\"\n", message)
	fmt.Printf(" 密钥: \"%s\"\n", string(secret))
	fmt.Printf(" HMAC-SHA256: %x\n", signature)
	h2 := hmac.New(sha256.New, []byte("my-secret-key")) // 1. 用相同的密钥创建新的 HMAC 对象
	h2.Write([]byte(message))                           // 2. 写入相同的消息
	expectedSignature := h2.Sum(nil)                    // 3. 计算出期望的签名
	isValid := hmac.Equal(signature, expectedSignature) // 4. 比对两个签名是否相等
	fmt.Printf(" 签名验证: %v\n", isValid)
}

func add10(a *int) {
	*a += 10
}

func doubleValue(a *[]int) {
	for i := range *a {
		(*a)[i] *= 2
	}
}

type Shape interface {
	Area() float64
	Perimeter() float64
}

type Rectangle struct {
	Width  float64
	Height float64
}

func (r Rectangle) Area() float64 {
	return r.Width * r.Height
}

func (r Rectangle) Perimeter() float64 {
	return 2 * (r.Width + r.Height)
}

type Circle struct {
	Radius float64
}

func (c Circle) Area() float64 {
	return 3.14 * c.Radius * c.Radius
}

func (c Circle) Perimeter() float64 {
	return 2 * 3.14 * c.Radius
}

type Person struct {
	Name string
	Age  int
}

type Employee struct {
	Person
	EmployeeID string
}

func (e Employee) PrintInfo() string {
	return fmt.Sprintf("Name: %s, Age: %d, EmployeeID: %s", e.Name, e.Age, e.EmployeeID)
}

func ChannelCommunication() {
	ch := make(chan int)
	var wg sync.WaitGroup
	wg.Add(2)
	go Producer(ch, &wg)
	go Consumer(ch, &wg)
	wg.Wait()
	fmt.Println("所有协程执行完毕")
}

func Producer(ch chan<- int, wg *sync.WaitGroup) {
	defer wg.Done()
	for i := 1; i <= 100; i++ {
		fmt.Printf("生产者发送：%d\n", i)
		ch <- i
	}
	close(ch)
}

func Consumer(ch <-chan int, wg *sync.WaitGroup) {
	defer wg.Done()
	for num := range ch {
		fmt.Printf("消费者接收：%d\n", num)
	}
}

func ChannelWithBufferCommunication() {
	ch := make(chan int, 100)
	var wg sync.WaitGroup
	wg.Add(2)
	go Producer(ch, &wg)
	go SlowConsumer(ch, &wg)
	wg.Wait()
	fmt.Println("所有协程执行完毕")
}

func SlowConsumer(ch <-chan int, wg *sync.WaitGroup) {
	defer wg.Done()
	for num := range ch {
		fmt.Printf("消费者接收：%d\n", num)
		time.Sleep(1000 * time.Millisecond)
	}
}

type SafeCounter struct {
	mu    sync.Mutex
	count int
}

func NewSafeCounter() *SafeCounter {
	return &SafeCounter{}
}

func (sc *SafeCounter) Increment(m int) {
	sc.mu.Lock()
	for i := 0; i < 1000; i++ {
		sc.count++
	}
	fmt.Printf("goroutine %d incremented counter %d\n", m, sc.count)
	sc.mu.Unlock()
}
func mutexDemo() {
	fmt.Println("=== Mutex示例 ===")

	counter := NewSafeCounter()
	var wg sync.WaitGroup

	// 启动多个goroutine并发增加计数器
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			counter.Increment(i)
		}(i)
	}

	wg.Wait()
	fmt.Printf("最终计数: %d (期望: 10000)\n\n", counter.GetCount())
}

func (sc *SafeCounter) GetCount() int {
	sc.mu.Lock()
	defer sc.mu.Unlock()
	return sc.count
}
func AtomicAdd() {
	var wg sync.WaitGroup
	var atomicCounter int64
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < 1000; j++ {
				atomic.AddInt64(&atomicCounter, 1)
			}
		}()
	}
	wg.Wait()
	fmt.Printf("atomic counter result: %d (期望: 10000)\n", atomicCounter)
}
