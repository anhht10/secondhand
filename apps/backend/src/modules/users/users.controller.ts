import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiErrorResponseDto } from '../../common/dto/api-response.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { ParseObjectIdPipe } from '../../common/pipes/parse-object-id.pipe';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UpdateUserDto } from './dto/update-user.dto';
import {
  PublicSellerProfileResponseDto,
  UserResponseDto,
} from './dto/user-response.dto';
import { UsersService } from './users.service';

@ApiTags('Users')
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get authenticated user profile' })
  @ApiResponse({
    status: 200,
    description: 'Current user profile returned',
    type: UserResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  async getMe(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.usersService.getMeWithStats(currentUser.userId);
  }

  @Patch('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update authenticated user profile' })
  @ApiResponse({
    status: 200,
    description: 'User profile updated',
    type: UserResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Validation error',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  async updateMe(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() updateDto: UpdateUserDto,
  ) {
    const updated = await this.usersService.updateProfile(
      currentUser.userId,
      updateDto,
    );
    const stats = await this.usersService.computeUserStats(currentUser.userId);
    return this.usersService.sanitizeUser(updated, stats);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get public seller profile by user ID' })
  @ApiParam({ name: 'id', description: 'User MongoDB ObjectId' })
  @ApiResponse({
    status: 200,
    description: 'Public seller profile returned',
    type: PublicSellerProfileResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'User not found',
    type: ApiErrorResponseDto,
  })
  async getPublicProfile(@Param('id', ParseObjectIdPipe) id: string) {
    return this.usersService.findPublicProfileById(id);
  }
}
