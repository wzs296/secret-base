package controllers

import (
	"strconv"
	"webproject/config"
	"webproject/models"
	"webproject/utils"

	"github.com/gin-gonic/gin"
)

type PostController struct{}

type CreatePostRequest struct {
	Title   string `json:"title" bingding:"required,min=1.max=200"`
	Content string `json:"content" binding:"required,min=1"`
}

type UpdatePostRequest struct {
	Title   string `json:"title" bingding:"required,min=1.max=200"`
	Content string `json:"content" binding:"required,min=1"`
}

func (pc *PostController) CreatePost(c *gin.Context) {
	var req CreatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequest(c, err.Error())
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		utils.Unauthorized(c, "User not authenticated")
		return
	}

	post := models.Post{
		Title:   req.Title,
		Content: req.Content,
		UserID:  userID.(uint),
	}

	if err := config.DB.Create(&post).Error; err != nil {
		utils.InternalServerError(c, "Failed to create post")
		return
	}

	// 预加载用户信息
	config.DB.Preload("User").First(&post, post.ID)

	utils.Success(c, post)
}

// GetComments 获取文章的评论列表
func (pc *PostController) GetPosts(c *gin.Context) {
	var posts []models.Post

	// 分页参数
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	offset := (page - 1) * pageSize

	// 查询评论列表，预加载用户信息
	if err := config.DB.Preload("User").
		Order("created_at ASC").
		Limit(pageSize).
		Offset(offset).
		Find(&posts).Error; err != nil {
		utils.InternalServerError(c, "Failed to get posts")
		return
	}

	// 获取总数
	var total int64
	config.DB.Model(&models.Post{}).Count(&total)

	utils.Success(c, gin.H{
		"posts":     posts,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	})
}

func (pc *PostController) GetPost(c *gin.Context) {
	postID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequest(c, "Invalid post ID")
		return
	}

	// 检查文章是否存在
	var post models.Post
	if err := config.DB.Preload("User").Preload("Comments.User").First(&post, postID).Error; err != nil {
		utils.NotFound(c, "Post not found")
		return
	}

	utils.Success(c, post)
}

func (pc *PostController) UpdatePost(c *gin.Context) {
	postID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequest(c, "Invalid post ID")
		return
	}
	var req UpdatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequest(c, err.Error())
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		utils.Unauthorized(c, "User not authenticated")
		return
	}
	// 检查文章是否存在
	var post models.Post
	if err := config.DB.First(&post, postID).Error; err != nil {
		utils.NotFound(c, "Post not found")
		return
	}
	if post.UserID != userID.(uint) {
		utils.Forbidden(c, "You can only update your own posts")
		return
	}

	post.Title = req.Title
	post.Content = req.Content

	if err := config.DB.Save(&post).Error; err != nil {
		utils.InternalServerError(c, "Failed to update post")
	}
	config.DB.Preload("User").First(&post, post.ID)
	utils.Success(c, post)
}

func (pc *PostController) DeletePost(c *gin.Context) {
	postID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequest(c, "Invalid post ID")
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		utils.Unauthorized(c, "User not authenticated")
		return
	}
	// 检查文章是否存在
	var post models.Post
	if err := config.DB.First(&post, postID).Error; err != nil {
		utils.NotFound(c, "Post not found")
		return
	}
	if post.UserID != userID.(uint) {
		utils.Forbidden(c, "You can only delete your own posts")
		return
	}

	if err := config.DB.Delete(&post).Error; err != nil {
		utils.InternalServerError(c, "Failed to delete post")
	}
	config.DB.Preload("User").First(&post, post.ID)

	utils.Success(c, gin.H{"message": "Post deleted successfully"})
}
