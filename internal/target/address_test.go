package target_test

import (
	"testing"

	"github.com/hashicorp/boundary/internal/errors"
	"github.com/hashicorp/boundary/internal/target"
	"github.com/hashicorp/boundary/internal/target/store"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestTargetAddress_New(t *testing.T) {
	type args struct {
		publicId string
		address  string
	}
	tests := []struct {
		name    string
		args    args
		want    *target.TargetAddress
		wantErr errors.Code
	}{
		{
			name: "no-public_id",
			args: args{
				address: "0.0.0.0",
			},
			wantErr: errors.InvalidParameter,
		},
		{
			name: "no-address",
			args: args{
				publicId: "targ_0000000",
			},
			wantErr: errors.InvalidParameter,
		},
		{
			name: "valid",
			args: args{
				publicId: "targ_0000000",
				address:  "0.0.0.0",
			},
			want: &target.TargetAddress{
				TargetAddress: &store.TargetAddress{
					PublicId: "targ_0000000",
					Address:  "0.0.0.0",
				},
			},
		},
	}
	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			assert, require := assert.New(t), require.New(t)
			got, err := target.NewTargetAddress(tt.args.publicId, tt.args.address)
			if tt.wantErr != 0 {
				assert.Truef(errors.Match(errors.T(tt.wantErr), err), "want err: %q got: %q", tt.wantErr, err)
				assert.Nil(got)
				return
			}
			require.NoError(err)
			require.NotNil(got)
			assert.EqualValues(tt.want, got)
		})
	}
}
