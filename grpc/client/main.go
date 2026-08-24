package main

import (
	"context"
	"log"

	pb "secret-base/grpc/pb"

	"google.golang.org/grpc"
)

func main() {
	conn, err := grpc.Dial("127.0.0.1:50051", grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect:%v", err)
	}
	defer conn.Close()
	client := pb.NewUserServiceClient(conn)
	resp, err := client.GetUser(context.Background(), &pb.GetUserRequest{Id: 123})
	if err != nil {
		log.Fatalf("Call GetUserFailed:%v", err)
	}
	log.Printf("user:%+v", resp.User)
}
