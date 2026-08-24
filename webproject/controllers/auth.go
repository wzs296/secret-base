package controllers

import (
	"webproject/config"
	"webproject/models"
	"webproject/utils"

	"github.com/gin-gonic/gin"
)

type AuthController struct{}
type RegisterRequest struct {
	Username string `json:"username" binding:"required,min=3,max=20"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type AuthResponse struct {
	Token string      `json:"token"`
	User  models.User `json:"user"`
}

func (ac *AuthController) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequest(c, err.Error())
		return
	}

	var existingUser models.User
	if err := config.DB.Where("username=?", req.Username).First(&existingUser).Error; err == nil {
		utils.BadRequest(c, "Username already exists")
		return
	}
	if err := config.DB.Where("email=?", req.Username).First(&existingUser).Error; err == nil {
		utils.BadRequest(c, "Email already exists")
		return
	}
	user := models.User{
		Username: req.Username,
		Email:    req.Email,
		Password: req.Password,
	}
	if err := config.DB.Create(&user).Error; err != nil {
		utils.InternalServerError(c, "Failed to create user")
		return
	}

	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		utils.InternalServerError(c, "Fail to generate token")
		return
	}

	utils.Success(c, AuthResponse{
		Token: token,
		User:  user,
	})
}

func (ac *AuthController) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequest(c, err.Error())
		return
	}
	var user models.User
	if err := config.DB.Where("username=?", req.Username).First(&user).Error; err != nil {
		utils.BadRequest(c, "Invalid username or password")
		return
	}
	if !user.CheckPassword(req.Password) {
		utils.Unauthorized(c, "Invalid username or password")
		return
	}
	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		utils.InternalServerError(c, "Fail to generate token")
		return
	}

	utils.Success(c, AuthResponse{
		Token: token,
		User:  user,
	})
}

func (ac *AuthController) GetProfile(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		utils.Unauthorized(c, "User not authenticated")
		return
	}
	var user models.User
	if err := config.DB.First(&user, userID).Error; err != nil {
		utils.NotFound(c, "User not found")
		return
	}
	utils.Success(c, user)

}
