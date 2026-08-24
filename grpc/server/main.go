package main

import (
	"context"
	"log"
	"net"

	pb "secret-base/grpc/pb"

	"google.golang.org/grpc"
)

type server struct {
	pb.UnimplementedUserServiceServer
}

func (s *server) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.GetUserResponse, error) {
	log.Printf("收到请求：id=%d", req.Id)
	return &pb.GetUserResponse{
		User: &pb.User{
			Id:    req.Id,
			Name:  "崔湘吉子",
			Email: "unknown@unknown.com",
		},
	}, nil
}

func main() {
	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatalf("fail to listen:%v", err)
	}
	s := grpc.NewServer()
	pb.RegisterUserServiceServer(s, &server{})
	log.Println("gRPC server listening on :50051")
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve:%v", err)
	}
}
