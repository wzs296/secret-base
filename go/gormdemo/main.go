package main

import (
	"fmt"
	"log"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// User 定义数据库模型
// GORM 会自动根据结构体生成表 user
// 字段名默认会映射为 user 表中的列名
// 例如：ID -> id, Name -> name, Age -> age
//
// 如果使用 sqlite，运行后会在当前目录生成 gormdemo.db 文件
//
// 注意：使用 `gorm` 时，表名默认是结构体名的小写复数，如 `users`
// 这里结构体名是 `User`，所以默认表名一般是 `users`
// 但因为 sqlite 采用默认 naming strategy，实际表名可能是 `users`
// 若你想精确指定表名，可以加 `gorm:"tableName:users"`
//
// 下面的示例演示：创建、查询、更新、删除

type User struct {
	ID    uint   `gorm:"primaryKey"`
	Name  string `gorm:"size:128;not null"`
	Age   int    `gorm:"not null"`
	Email string `gorm:"uniqueIndex;size:255;not null"`

	Posts      []Post `gorm:"foreignKey:UserID;references:ID"`
	PostsCount int    `gorm:"column:posts_count;default:0;not null"`
	CreatedAt  time.Time
	UpdatedAt  time.Time
}
type Post struct {
	ID             uint      `gorm:"primaryKey"`
	Title          string    `gorm:"size:255;not null"`
	Content        string    `gorm:"type:text"`
	Comments       []Comment `gorm:"foreignKey:PostId;references:ID"`
	UserId         uint
	CommentsStatus string `gorm:"column:comments_status;size:32;default:'有评论';not null"`
}

type Comment struct {
	ID      uint   `gorm:"primaryKey"`
	Content string `gorm:"type:text"`
	PostId  uint
}

func main() {
	// 1. 连接数据库
	// sqlite 文件会在当前目录生成：gormdemo.db
	db, err := gorm.Open(sqlite.Open("gormdemo.db"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		log.Fatalf("连接数据库失败: %v", err)
	}

	// 2. 自动迁移（创建表/更新表结构）
	if err = db.AutoMigrate(&User{}, &Post{}, &Comment{}); err != nil {
		log.Fatalf("自动迁移失败: %v", err)
	}

	// 3. 创建数据
	user := User{
		Name:  "Alice",
		Age:   18,
		Email: "alice@example.com",
		Posts: []Post{
			{Title: "七夕节和水果呢", Content: "这是alice和我一起过", Comments: []Comment{{
				Content: "xiaosiwole"},
			}},
			{Title: "what is love", Content: "love is being with zuoshiwu", Comments: []Comment{{
				Content: "make me laugh"}, {Content: "so funny"},
			}},
		},
	}
	result := db.Create(&user)
	if result.Error != nil {
		log.Fatalf("写入数据失败: %v", result.Error)
	}
	fmt.Printf("创建成功，ID=%d\n", user.ID)

	Search(db)
	GetMost(db)
	AddPostForUser(db, 1, "new post", "nothing")
}

func Search(db *gorm.DB) {
	var user User
	err := db.Preload("Posts").Preload("Posts.Comments").First(&user, 1).Error
	if err != nil {
		log.Fatalf("查询失败:%v", err)
	}
	fmt.Println("用户:", user.Name)
	for _, post := range user.Posts {
		fmt.Printf("文章: %s\n", post.Title)
		for _, comment := range post.Comments {
			fmt.Printf("  评论: %s\n", comment.Content)
		}
	}
}
func GetMost(db *gorm.DB) {
	type PostCount struct {
		ID            uint
		Title         string
		Content       string
		UserId        uint
		CommentsCount int64
	}
	top := PostCount{}
	_ = db.Model(&Post{}).Select("posts.id,posts.title,posts.content,posts.user_id,count(comments.id) AS comments_count").
		Joins("LEFT JOIN comments ON comments.post_id= posts.id").
		Group("posts.id").
		Order("comments_count DESC").
		Limit(1).
		Scan(&top).Error
	fmt.Printf("Top post: %+v\n", top)
}
func (p *Post) AfterCreate(tx *gorm.DB) (err error) {
	if p.UserId == 0 {
		return nil
	}
	return tx.Model(&User{}).Where("id=?", p.UserId).UpdateColumn("posts_count", gorm.Expr("posts_count+?", 1)).Error
}
func AddPostForUser(db *gorm.DB, userID uint, title, content string) (*Post, error) {
	post := &Post{
		Title:   title,
		Content: content,
		UserId:  userID,
	}

	err := db.Transaction(func(tx *gorm.DB) error {
		var u User
		if err := tx.First(&u, userID).Error; err != nil {
			return err
		}
		if err := tx.Create(post).Error; err != nil {
			return err
		}
		// 如果你更倾向于在这里显式更新计数（而不是依赖 AfterCreate），取消注释下面一行：
		// return tx.Model(&User{}).Where("id = ?", userID).UpdateColumn("posts_count", gorm.Expr("posts_count + ?", 1)).Error
		return nil
	})
	if err != nil {
		return nil, err
	}

	// 可选：返回时预加载评论
	if err := db.Preload("Comments").First(post, post.ID).Error; err != nil {
		return nil, err
	}
	return post, nil
}
func (c *Comment) AfterDelete(tx *gorm.DB) (err error) {
	var count int64
	if err = tx.Model(&Comment{}).Where("post_id=?", c.PostId).Count(&count).Error; err != nil {
		return err
	}
	if count == 0 {
		return tx.Model(&Post{}).Where("id=?", c.PostId).
			UpdateColumn("comments_status", "无评论").Error
	}
	return nil

}
func DeleteCommentByID(db *gorm.DB, commentID uint) error {
	return db.Transaction(func(tx *gorm.DB) error {
		var c Comment
		if err := tx.First(&c, commentID).Error; err != nil {
			return err
		}
		if err := tx.Delete(&c).Error; err != nil {
			return err
		}

		return nil
	})
}
