package controllers

import (
	"strconv"
	"webproject/config"
	"webproject/models"
	"webproject/utils"

	"github.com/gin-gonic/gin"
)

type CommentController struct{}

type CreateCommentRequest struct {
	Content string `json:"content" binding:"required,min=1,max=1000"`
}

func (cc *CommentController) CreateComment(c *gin.Context) {
	postID, err := strconv.ParseUint(c.Param("post_id"), 10, 31)
	if err != nil {
		utils.BadRequest(c, "inavalid post ID")
		return
	}

	var req CreateCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequest(c, err.Error())
		return
	}
	userID, exists := c.Get("user_id")
	if !exists {
		utils.Unauthorized(c, "User not authenticated")
		return
	}
	var post models.Post
	if err := config.DB.First(&post, postID).Error; err != nil {
		utils.NotFound(c, "Post not found")
		return
	}
	comment := models.Comment{
		Content: req.Content,
		UserId:  userID.(uint),
		PostID:  uint(postID),
	}

	if err := config.DB.Create(&comment).Error; err != nil {
		utils.InternalServerError(c, "Failed to create comment")
		return
	}
	config.DB.Preload("User").First(&comment, comment.ID)
	utils.Success(c, comment)
}

func (cc *CommentController) GetComments(c *gin.Context) {
	postID, err := strconv.ParseUint(c.Param("post_id"), 10, 31)
	if err != nil {
		utils.BadRequest(c, "inavalid post ID")
		return
	}
	var post models.Post
	if err := config.DB.First(&post, postID).Error; err != nil {
		utils.NotFound(c, "Post not found")
		return
	}
	var comments []models.Comment

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize
	if err := config.DB.Preload("User").
		Where("post_id=?", postID).
		Order("created_at ASC").
		Limit(pageSize).
		Offset(offset).
		Find(&comments).Error; err != nil {
		utils.InternalServerError(c, "Failed to get comments")
		return
	}

	var total int64
	config.DB.Model(&models.Comment{}).Where("post_id=?", postID).Count(&total)

	utils.Success(c, gin.H{
		"comments":  comments,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	})
}
