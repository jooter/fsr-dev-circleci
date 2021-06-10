# in sub package directory
go test -coverprofile=prof.out
go tool cover -html=prof.out
