import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { BlogsService } from './blogs.service';
import {
  CreateBlogCommentDto,
  CreateBlogPostDto,
  GenerateAiBlogDraftDto,
  QueryBlogPostsDto,
  UpdateBlogPostDto,
} from './dto/blog.dto';

@ApiTags('Community Blog & Articles')
@Controller('blogs')
export class BlogsController {
  constructor(private readonly blogsService: BlogsService) {}

  @Get()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List paginated community blog posts with filters' })
  async findAll(
    @Query() queryDto: QueryBlogPostsDto,
    @CurrentUser() user?: AuthenticatedUser,
  ) {
    return this.blogsService.findAll(queryDto, user?.userId);
  }

  @Post('ai-draft')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Generate an AI-assisted blog post draft from topic & key points',
  })
  async generateAiDraft(@Body() dto: GenerateAiBlogDraftDto) {
    return this.blogsService.generateAiDraft(dto);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Get blog post detail with comments and attached product',
  })
  async findById(
    @Param('id') id: string,
    @CurrentUser() user?: AuthenticatedUser,
  ) {
    return this.blogsService.findById(id, user?.userId);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a new community blog post' })
  async create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateBlogPostDto,
  ) {
    return this.blogsService.create(user.userId, dto);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update an existing blog post (author only)' })
  async update(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdateBlogPostDto,
  ) {
    return this.blogsService.update(id, user.userId, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete a blog post (author only)' })
  async remove(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.blogsService.remove(id, user.userId);
  }

  @Post(':id/like')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Toggle like on a blog post' })
  async toggleLike(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.blogsService.toggleLike(id, user.userId);
  }

  @Get(':id/comments')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get comments for a blog post' })
  async getComments(@Param('id') id: string) {
    return this.blogsService.getComments(id);
  }

  @Post(':id/comments')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Add a comment to a blog post' })
  async addComment(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateBlogCommentDto,
  ) {
    return this.blogsService.addComment(id, user.userId, dto);
  }

  @Delete(':id/comments/:commentId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete a comment (comment author or post author)' })
  async deleteComment(
    @Param('id') id: string,
    @Param('commentId') commentId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.blogsService.deleteComment(id, commentId, user.userId);
  }
}
