package routes

import (
	"webproject/controllers"
	"webproject/middleware"

	"github.com/gin-gonic/gin"
)

func SetupRoutes() *gin.Engine {

	r := gin.New()
	r.Use(middleware.LoggerMiddleware())
	r.Use(middleware.ErrorHandlerMiddleware())
	r.Use(gin.Recovery())

	authController := &controllers.AuthController{}
	postController := &controllers.PostController{}
	commentController := &controllers.CommentController{}

	api := r.Group("/api/v1")
	{
		auth := api.Group("/auth")
		{
			auth.POST("/register", authController.Register)
			auth.POST("/login", authController.Login)
		}
		authenticated := api.Group("")
		authenticated.Use(middleware.AuthMiddleware())
		{
			authenticated.GET("/profile", authController.GetProfile)

			posts := authenticated.Group("/post")
			{
				posts.POST("", postController.CreatePost)
				posts.PUT("/:id", postController.UpdatePost)
				posts.DELETE("/:id", postController.DeletePost)
			}

			comments := authenticated.Group("/posts/:post_id/comments")
			{
				comments.POST("", commentController.CreateComment)
			}
		}
		public := api.Group("")
		{
			public.GET("/posts", postController.GetPosts)
			public.GET("/posts/:id", postController.GetPost)
		}
		comments := api.Group("/comments")
		{
			comments.GET("/post/:post_id", commentController.GetComments)
		}

	}
	r.GET("/health", func(ctx *gin.Context) {
		ctx.JSON(200, gin.H{
			"status":  "ok",
			"message": "Blog API is running",
		})
	})
	return r
}
